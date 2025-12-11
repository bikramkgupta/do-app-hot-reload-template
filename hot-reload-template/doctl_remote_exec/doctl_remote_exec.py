import pexpect
import sys
import re

def execute_doctl_command(app_id, component_name, command_to_run):
    """
    Connects to a DigitalOcean App Platform component console using doctl, 
    executes a command, and returns the output.
    """
    
    # 1. Construct the doctl command
    doctl_cmd = f"doctl apps console {app_id} {component_name}"
    
    print(f"Attempting to run command on component '{component_name}'...")
    print(f"Command: '{command_to_run}'")
    
    # --- PROMPT FIX ---
    # The prompt pattern should be as simple as possible but still unique.
    # The last part of your prompt is always ':/workspaces/app$ ' (or similar).
    # We will look for an ending that is a dollar sign followed by a space.
    # We use 'b' for byte string patterns as pexpect works with bytes.
    # The pattern should be compiled *outside* the function if possible for performance,
    # but for simplicity, we'll define a byte-string pattern here.
    #PROMPT = re.compile(b'\\$ ') 
    PROMPT = re.compile(b'devcontainer@[^:]+:[^$]+\\$ ')
    
    try:
        # 2. Spawn the interactive process
        child = pexpect.spawn(doctl_cmd, timeout=30)
        
        # Disable echo and set small delays for a faster, cleaner session
        child.setecho(False)
        child.delayafterread = 0.05
        child.delayafterwrite = 0.05

        # 3. Wait for the initial shell prompt
        # We wait for the first appearance of the simplified '$ ' prompt.
        print("Waiting for prompt...")
        child.expect(PROMPT, timeout=30)
        
        # 4. Execute the desired command
        child.sendline(command_to_run)
        
        # 5. Wait for the command to finish and the prompt to reappear
        # This will capture everything *after* the command is sent and *before* the next prompt.
        print("Command sent, waiting for output...")
        child.expect(PROMPT, timeout=30)
        
        # 6. Get the raw output (decodes to string)
        raw_output = child.before.decode('utf-8', errors='ignore')
        
        # 7. Clean up the output
        # Find the command that was echoed back by the shell and remove it.
        # This usually has a leading newline/carriage return.
        
        # This is a bit safer: split the output, find the command, and take the rest.
        lines = raw_output.splitlines()
        
        # Find the index of the line containing the command
        start_index = -1
        for i, line in enumerate(lines):
            # The command is often prefixed by the user input path, but we can look for the command itself
            if command_to_run in line.strip():
                start_index = i
                break
        
        # The actual output starts *after* the command line
        if start_index != -1 and start_index + 1 < len(lines):
             # Join all lines from the command's immediate next line to the end.
             cleaned_output = "\n".join(lines[start_index + 1:]).strip()
        else:
             # Fallback cleanup for edge cases
             cleaned_output = raw_output.replace(command_to_run, '', 1).strip()
             
        
        # 8. Send the exit command and close the session
        print("Exiting console...")
        child.sendline("exit")
        # We don't need to wait for exit, just close cleanly.
        child.close()
        
        return cleaned_output

    # --- EXCEPTION FIX ---
    except pexpect.exceptions.TIMEOUT:
        print("\n--- ERROR: Timed out waiting for prompt or command completion. ---", file=sys.stderr)
        return None
    except pexpect.exceptions.EOF:
        print("\n--- ERROR: Console closed unexpectedly (EOF). ---", file=sys.stderr)
        # If the console closed, the last received data is in child.before
        return child.before.decode('utf-8').strip() if 'child' in locals() else None
    except Exception as e:
        print(f"\n--- An unexpected error occurred: {e} ---", file=sys.stderr)
        return None

# --- Main Execution Block ---
if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(f"Usage: python {sys.argv[0]} <app-id> <component-name> \"<command-to-run>\"")
        print("Example: python doctl_remote_exec.py e6cd... dev-workspace-bun \"ls -l\"")
        sys.exit(1)

    app_id = sys.argv[1]
    component_name = sys.argv[2]
    command_to_run = sys.argv[3]

    result = execute_doctl_command(app_id, component_name, command_to_run)

    if result is not None:
        print("\n" + "="*50)
        print("✅ Remote Command Output:")
        print("="*50)
        print(result)
        print("="*50)
    else:
        sys.exit(1) # Exit with an error code if execution failed
