#### Name

Windows - Remove Automatic Updates  | v1.0 JCCG

#### commandType

windows

#### Command

```
## Removes the task "JCWindowsUpdates" 
## Removes the update script "JC_ScheduledWindowsUpdate.ps1"


SCHTASKS /Delete /tn "JCWindowsUpdates" /F

$FileName = 'JC_ScheduledWindowsUpdate.ps1'
$FilePath = "C:\Windows\Temp\JC_ScheduledTasks\$FileName"

Remove-Item -Path $FilePath

```

#### Description

This command removes the scheduled task named "\JCWindowsUpdates" and removes the file 'JC_ScheduledWindowsUpdate.ps1' called by this scheduled task.

### Dependencies

This command is intended to be run after automatic updates are scheduled to be run under the task named "\JCWindowsUpdates" and is a roll back plan for the
the command [Windows - Schedule Automatic Updates](https://github.com/TheJumpCloud/support/blob/master/PowerShell/JumpCloud%20Commands%20Gallery/Windows%20Commands/Windows%20Updates/Windows%20-%20Schedule%20Automatic%20Updates.md)


#### *Import This Command*

To import this command into your JumpCloud tenant run the below command using the [JumpCloud PowerShell Module](https://github.com/TheJumpCloud/support/wiki/Installing-the-JumpCloud-PowerShell-Module)

```
Import-JCCommand -URL 'https://git.io/jccg-Windows-RemoveAutomaticUpdates'
```

#### Related Commands
- [Schedule Automatic Updates](https://github.com/TheJumpCloud/support/blob/master/PowerShell/JumpCloud%20Commands%20Gallery/Windows%20Commands/Windows%20Updates/Windows%20-%20Schedule%20Automatic%20Updates.md)
- [Run Automatic Updates](https://github.com/TheJumpCloud/support/blob/master/PowerShell/JumpCloud%20Commands%20Gallery/Windows%20Commands/Windows%20Updates/Windows%20-%20Run%20Automatic%20Updates.md)
- [Show Installed Updates](https://github.com/TheJumpCloud/support/blob/master/PowerShell/JumpCloud%20Commands%20Gallery/Windows%20Commands/Windows%20Updates/Windows%20-%20Show%20Installed%20Updates.md)
