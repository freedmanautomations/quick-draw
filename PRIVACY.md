# Privacy

Quick Draw stores only the tools you choose, their labels and targets, and the floating button's position. Application targets are local paths. Website targets can contain information you enter in their address, so avoid saving addresses that contain access tokens or private query strings.

The launcher does not send those settings anywhere. There is no account, telemetry, listening server, cloud connection, clipboard reader, microphone recorder or screen capture. It does not enumerate your installed apps or read the documents belonging to them.

A selected app's name and identity are read when adding or launching it. The selected app or browser remains responsible for its own data and network behavior.

Tools are in `~/Library/Application Support/Quick Draw/`. Button position uses the preference domain `org.quickdraw.launcher`. You can remove those files after quitting if you want to remove the local settings. Settings recovery retains an unreadable file as a local backup; it does not upload it.
