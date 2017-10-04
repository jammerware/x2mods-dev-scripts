# Jammerware's XCOM 2 Mod Dev Scripts

## Death to Visual Studio and its MSBuildy bretheren
Don't get me wrong. I spent years of my life happily working in Visual Studio and its associated products. Then, one day, after the third time Visual Studio got upset that I deleted a file in a way that it didn't expect and crashed itself in protest, I realized there had to be a better way. Now that I'm a citizen of the wonderful world of text-editor-based development, I can't go back to the bad old days.

You can imagine, then, my consternation when I installed the XCOM 2 SDK and opened ModBuddy for the first time. It all came screaming back. The `sln` files, the templates, the crashing - all of it. Visual Studio served us well for an age, but a new age has dawned. In this age, MSBuild can go die in a fire.

This repository contains powershell scripts that you can use with your favorite text editor to develop XCOM 2 mods. You'll still need the SDK, including ModBuddy, to _create_ a new mod, but once you're rolling, smart integration of these scripts with your text editor can make the development process a lot less painful.

## Example usage
For all the smack I talk about Visual Studio, my text-editing apple didn't fall far from the tree. I'm now working in [Visual Studio Code](https://code.visualstudio.com/). I'm fairly confident that competing editors like [Atom](https://atom.io/) have similar task workflows, but here's my `tasks.json` for VS Code that uses these scripts:

```
{
    "version": "2.0.0",
    "tasks": [
        {
            "taskName": "build",
            "type": "shell",
            "command": "powershell.exe -file '${workspaceRoot}/scripts/build.ps1' -mod 'JammerwareRunnerClass' -srcDirectory '${workspaceRoot}' -sdkPath 'D:/Steam/steamapps/common/XCOM 2 War of the Chosen SDK' -gamePath 'D:/Steam/steamapps/common/XCOM 2'",
            "group": {
                "kind": "build",
                "isDefault": true
            }
        },
        {
            "taskName": "debug",
            "type": "shell",
            "command": "powershell.exe -file '${workspaceRoot}/scripts/run.ps1' -gamePath 'D:/Steam/steamapps/common/XCOM 2'"
        },
        {
            "taskName": "runUnrealEditor",
            "type": "shell",
            "command": "powershell.exe -file '${workspaceRoot}/scripts/runUnrealEditor.ps1' -gamePath 'D:/Steam/steamapps/common/XCOM 2 War of the Chosen SDK'"
        }
    ]
}
```

Just drop the scripts into a `scripts` directory in the root of your mod project, set up your `tasks.json` similar to the above (don't forget to update the paths being passed into the powershell scripts to point to your SDK and game installations), and you're good to go. Probably, anyway.

## About the scripts
- **build.ps1**: This is by far the most involved script and is the one in which I see the most potential to help other modders. It's basically my attempt to reverse-engineer what happens when you hit "Build" in ModBuddy. It compiles your mod and copies its assets to the appropriate location for debug. 
- **run.ps1**: This is more or less functionally equivalent to running the `StartDebugging.bat` file that comes with the SDK. I just tossed it into a powershell script for better integration with some text editors.
- **runUnrealEditor.ps1**: This is just a stand-in for opening XCOM's Unreal Editor from the Tools menu in ModBuddy.

## Known issues
Because I didn't have time to be a paragon of good practice, there are a few issues right out of the box. Sorry.

- Currently, I don't have scripts to create or publish mod projects. Publish is definitely something I want to do, but I haven't had time to find out what happens when you click "Publish" in ModBuddy, not least because I haven't actually published a mod yet. This is on my short list.
- These scripts, as written, assume you have the War of the Chosen expansion and that you're building mods for it. If either of these assumptions don't apply to you, you can probably tweak the scripts to work, but caveat code monkey.
- The scripts rely on Powershell. Hey, I don't like it either.
- Breakpoint debugging isn't supported. This seems really hard to me, but that's possibly because I never really got it working with ModBuddy either. If you have suggestions on this, PR away!
- I'm actually super new to modding XCOM 2, and I've only horsed around with script and ini mods (not content ones). As a result, I kind of have a feeling that maybe this workflow that I've hacked together won't work for everyone (or maybe even anyone else). If you have suggestions about how these scripts can serve you better or an idea for a new one, feel free to submit a PR.