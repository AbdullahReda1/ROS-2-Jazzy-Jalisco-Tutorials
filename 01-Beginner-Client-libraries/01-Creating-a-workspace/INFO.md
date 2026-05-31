# Creating a ROS 2 Workspace

## ROS 2 Jazzy Jalisco | Beginner: Client Libraries

---

## 1. Workspaces, Overlays, and Underlays — With Concrete Examples

The tutorial paragraph says several distinct things. Let's break each one down with a real example.

---

### Concept A: "Source your ROS 2 installation workspace before using ROS 2"

This is the most basic case: you have exactly one workspace, the system-installed Jazzy, and you just activate it.

```bash
# Fresh terminal — ROS 2 is installed but invisible to this shell
ros2 run turtlesim turtlesim_node
# → bash: ros2: command not found

# Source the installation to activate it
source /opt/ros/jazzy/setup.bash

# Now the shell knows about ROS 2
ros2 run turtlesim turtlesim_node
# → turtlesim window opens ✓
```

In this scenario `/opt/ros/jazzy` is both your installation AND your only workspace. There is no overlay at all.

---

### Concept B: "An overlay — a secondary workspace where you can add new packages without interfering with the underlay"

You need to work on `turtlesim` without touching the system installation. You create a new workspace, clone `turtlesim` into it, build it, and use it as an overlay on top of Jazzy.

```text
/opt/ros/jazzy/          ← UNDERLAY (Jazzy system install — do not touch)
        +
~/ros2_ws/install/       ← OVERLAY (your workspace)
```

```bash
# Terminal 1 — build the overlay
source /opt/ros/jazzy/setup.bash            # activate underlay first
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws/src
git clone https://github.com/ros/ros_tutorials.git -b jazzy
cd ~/ros2_ws
colcon build --symlink-install

# Terminal 2 — use the overlay
source /opt/ros/jazzy/setup.bash                    # underlay
source ~/ros2_ws/install/local_setup.bash           # overlay on top
ros2 run turtlesim turtlesim_node
# → runs YOUR turtlesim, not /opt/ros/jazzy's
```

The key benefit: you can modify `turtlesim` in `~/ros2_ws/src/` and rebuild, while `/opt/ros/jazzy/` stays completely untouched. Another developer on the same machine who never sources your overlay still gets the original unmodified `turtlesim`.

---

### Concept C: "Your underlay must contain the dependencies of all the packages in your overlay"

Suppose your overlay package depends on `rclcpp`. That dependency is NOT cloned into `~/ros2_ws/src`. It lives in `/opt/ros/jazzy`. If you forget to source `/opt/ros/jazzy/setup.bash` before building (making it the underlay), cmake cannot find `rclcpp` and the build fails.

```bash
# WRONG — build without sourcing underlay
mkdir -p ~/ros2_ws/src && cd ~/ros2_ws
git clone https://github.com/ros/ros_tutorials.git src/
colcon build
# → CMake Error: find_package(rclcpp) could not find rclcpp
#   because the underlay (/opt/ros/jazzy) was never sourced

# CORRECT — source underlay first, then build
source /opt/ros/jazzy/setup.bash
colcon build
# → Finished <<< turtlesim ✓
```

This is why Step 1 of the tutorial ("Source ROS 2 environment") happens before Step 5 ("Build the workspace").

---

### Concept D: "Packages in your overlay will override packages in the underlay"

You have turtlesim in two places: `/opt/ros/jazzy` (underlay) and `~/ros2_ws/install` (overlay). After sourcing both, `ros2 run turtlesim turtlesim_node` runs the overlay version. You verified this in the tutorial by changing the window title to "MyTurtleSim" — only the overlay was affected.

```text
/opt/ros/jazzy → turtlesim (window title: "TurtleSim")      ← HIDDEN by overlay
~/ros2_ws/install → turtlesim (window title: "MyTurtleSim") ← ACTIVE (overlay wins)
```

The underlay is not deleted or harmed. Open a new terminal, source only `/opt/ros/jazzy/setup.bash`, and you get the original "TurtleSim" back.

---

### Concept E: "Several layers of underlays and overlays"

Imagine three workspaces chained together:

```text
/opt/ros/jazzy/              ← Layer 1 (base underlay — Jazzy system install)
      +
~/team_ws/install/           ← Layer 2 (team overlay — shared custom messages)
      +
~/my_ws/install/             ← Layer 3 (personal overlay — your robot node)
```

```bash
# In the terminal where you will run your robot node:
source /opt/ros/jazzy/setup.bash              # Layer 1 — provides rclcpp, rclpy, etc.
source ~/team_ws/install/local_setup.bash     # Layer 2 — provides your team's custom_msgs
source ~/my_ws/install/local_setup.bash       # Layer 3 — provides YOUR robot_node

ros2 run robot_node robot_driver
# → robot_driver uses custom_msgs (from Layer 2) and rclcpp (from Layer 1)
```

Each successive overlay can use everything from all layers below it. `~/my_ws` packages can `#include` headers from `~/team_ws` and from `/opt/ros/jazzy`. If a package exists in multiple layers, the topmost one (Layer 3) wins.

---

## 2. Why Put All Packages Inside `src/`?

This is about **separation of concerns** between the code you write and the files colcon generates.

When you run `colcon build`, it creates three new directories alongside wherever it finds your packages: `build/`, `install/`, and `log/`. If your packages were directly inside `ros2_ws/` (no `src/`), these generated directories would appear mixed in with your source code. That creates two serious problems.

The first problem is  **accidental package crawling** . colcon recursively scans the workspace root for `package.xml` files to discover packages. If `build/` and `install/` lived at the same level as your packages, colcon would need to either scan into them (slow, error-prone) or rely on explicit ignore markers everywhere inside them. The `build/` directory already contains a `COLCON_IGNORE` file precisely to prevent this — but that only works because `build/` is at the workspace root, not mixed among source packages. The `install/` directory also has an `AMENT_IGNORE` marker for the same reason.

The second problem is  **version control** . Your `src/` directory contains the code you want to commit to Git. The `build/`, `install/`, and `log/` directories contain generated machine-specific artifacts you never commit. Keeping `src/` as its own clean subdirectory makes your `.gitignore` trivial:

```text
# .gitignore at ros2_ws/ root:
build/
install/
log/
# everything in src/ gets tracked automatically ✓
```

The resulting layout makes intent immediately obvious:

```text
ros2_ws/
├── src/      ← YOU own this: source code, committed to Git
├── build/    ← colcon owns this: intermediate files, never commit
├── install/  ← colcon owns this: installed outputs, never commit
└── log/      ← colcon owns this: build logs, never commit
```

---

## 3. How `COLCON_IGNORE` Works

`COLCON_IGNORE` is an empty marker file. When colcon's package crawler descends into a directory and finds a file named `COLCON_IGNORE`, it immediately stops descending into that directory and all its subdirectories. No package inside that subtree will be discovered, configured, or built.

You saw this directly in the tutorial. The `ros_tutorials` repository contains four packages:

```text
src/ros_tutorials/
├── roscpp_tutorials/
│   ├── COLCON_IGNORE   ← colcon stops here, this package is skipped
│   └── package.xml
├── rospy_tutorials/
│   ├── COLCON_IGNORE   ← skipped
│   └── package.xml
├── ros_tutorials/
│   ├── COLCON_IGNORE   ← skipped
│   └── package.xml
└── turtlesim/
    └── package.xml     ← no COLCON_IGNORE → colcon builds this one
```

This is why your build output showed only one package despite cloning a repository with four. The `roscpp_tutorials`, `rospy_tutorials`, and `ros_tutorials` packages are ROS 1 packages that cannot build on ROS 2. Their maintainers placed `COLCON_IGNORE` files in them so anyone cloning the repository on ROS 2 builds only `turtlesim`.

You can use this yourself in any scenario where you want to temporarily disable a package without deleting it:

```bash
# Disable a package without removing it:
touch src/my_broken_package/COLCON_IGNORE

# Re-enable it:
rm src/my_broken_package/COLCON_IGNORE
```

The file must be named exactly `COLCON_IGNORE` with no extension and placed directly inside the directory you want to skip. Placement in a subdirectory would only block that subdirectory's children, not the package at the current level.

---

## 4. `rosdep` — Full Deep Dive

### What is rosdep?

`rosdep` is a command-line tool that reads the `<depend>` tags in every `package.xml` file in your workspace and installs any missing system-level dependencies using the platform's native package manager (on Ubuntu: `apt`; on macOS: Homebrew).

It bridges the gap between the ROS ecosystem's abstract dependency names and the concrete system package names that differ per OS and distribution. For example, a `package.xml` might declare `<depend>libopencv-dev</depend>` using an abstract name. The actual `apt` package on Ubuntu 24.04 is `libopencv-dev`, while on macOS it's the Homebrew formula `opencv`. rosdep knows this mapping — you declare the abstract name once, and rosdep resolves the correct install command for your platform.

### How rosdep Works — The Three-Layer Architecture

**Layer 1: The sources list** at `/etc/ros/rosdep/sources.list.d/20-default.list`
This file is written by `sudo rosdep init`. It contains URLs pointing to rosdep rule YAML files hosted on GitHub. These are the databases that map abstract dependency names to platform-specific package names.

**Layer 2: The rule files** — downloaded from those URLs during `rosdep update`:

* `base.yaml` — system libraries (OpenCV, Eigen, Boost, Qt5, etc.)
* `python.yaml` — Python packages
* `ruby.yaml` — Ruby packages
* `osx-homebrew.yaml` — macOS-specific overrides
* Per-distro YAML files (e.g., for jazzy) — ROS packages themselves

**Layer 3: The local cache** at `~/.ros/rosdep/sources.cache/`
`rosdep update` downloads all those YAML files and caches them locally. When you run `rosdep install`, it reads from the local cache — no internet connection is needed at install time, only during the `rosdep update` step.

### What "Resolving Package Dependencies" Means

When colcon builds your workspace, the C++ compiler needs header files and shared libraries to be installed on the system before it starts. "Resolving dependencies" means:

1. Reading each `package.xml` in `src/` and collecting all `<depend>`, `<build_depend>`, and `<exec_depend>` declarations
2. Mapping each abstract name to a concrete system package via the rosdep database
3. Checking whether that system package is already installed
4. Installing any that are missing using `sudo apt install`

"Resolved successfully" means: every library your CMakeLists.txt calls `find_package()` or `target_link_libraries()` for is already installed and findable on the system before the build starts.

### Why Run rosdep from the Workspace Root, Not from `src/`

The `--from-paths src` argument tells rosdep which directory to scan for `package.xml` files. You run the command from `ros2_ws/` (the root) because `src` in that argument is a  **relative path** . If you were inside `src/`, you would need to write `--from-paths .` instead. Running from the workspace root with `--from-paths src` mirrors the colcon convention — both tools are always invoked from `ros2_ws/` — and it makes your commands readable and consistent. It also allows scanning multiple source directories at once in the future (`--from-paths src vendor_pkgs another_src`) without changing your working directory.

### Why You Need to Install Dependencies — Aren't They Already in the Underlay?

The underlay (`/opt/ros/jazzy`) provides **already-compiled ROS packages** like `rclcpp`, `geometry_msgs`, and `tf2`. These are present and sourced. However, your packages may also depend on **non-ROS system libraries** that are not part of any ROS installation.

For `turtlesim` specifically, its `package.xml` declares dependencies on Qt5 widgets (for the GUI window) and other system libraries installed via `apt`, not via the ROS repository. If Ubuntu was freshly installed and you only added the ROS apt repository, you might have ROS but be missing Qt5. rosdep fills that gap.

Additionally, if your overlay needs a ROS package that is NOT in your underlay — for example, a custom messages package from a third-party repository that wasn't part of the Jazzy desktop install — rosdep would install it from the ROS apt repository.

The rule of thumb:  **rosdep installs system-level packages; the underlay provides pre-compiled ROS packages** . Together they ensure everything your overlay needs is present before `colcon build` starts.

### Where rosdep Finds Its Database

Your `rosdep update` output showed exactly where the database comes from. It downloads YAML files from the `ros/rosdistro` repository on GitHub. You can browse the actual files at `https://github.com/ros/rosdistro/tree/master/rosdep`. To find what system package a given rosdep key maps to, search for that key name in `base.yaml` or `python.yaml` in that repository.

### rosdep Command Reference

| Command                                             | Purpose                                                                                    |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `sudo rosdep init`                                  | One-time per-machine setup: writes the sources list to `/etc/ros/rosdep/sources.list.d/`   |
| `rosdep update`                                     | Downloads/refreshes the dependency database to `~/.ros/rosdep/sources.cache/`              |
| `rosdep install --from-paths src --ignore-src -y`   | Main command: scan `src/`, install missing system deps                                     |
| `rosdep check --from-paths src --ignore-src`        | Dry-run: lists what would be installed without installing                                  |
| `rosdep keys --from-paths src`                      | Lists all dependency keys declared in `package.xml`files under `src/`                      |
| `rosdep resolve <key>`                              | Shows what system package a given rosdep key maps to on your platform                      |

### Terminal Output Analysis — Step by Step

**Step 1: First `rosdep install` attempt fails**

```bash
rosdep install -i --from-path src --rosdistro jazzy -y
DeprecationWarning: pkg_resources is deprecated as an API
ERROR: your rosdep installation has not been initialized yet
```

Two things happened. The `DeprecationWarning` about `pkg_resources` is completely harmless — it is a Python internal packaging library being phased out in favor of `importlib.metadata`. rosdep itself still functions; this warning will be silenced in a future release. You will see it on every rosdep invocation because `/usr/bin/rosdep` is a Python script using that older import style.

The actual blocking error is that `sudo rosdep init` had never been run on this machine. rosdep needs the sources list file at `/etc/ros/rosdep/sources.list.d/20-default.list` to know where to download its database. That file does not exist until `sudo rosdep init` creates it. Without it, rosdep has no idea what URLs to consult.

**Step 2: `sudo apt update`**

Before running `sudo rosdep init`, you refreshed Ubuntu's package lists. This ensures apt knows about the latest package versions in all configured repositories. Your sources include the Egyptian Ubuntu mirror (`eg.archive.ubuntu.com`), the ROS 2 apt repository (`packages.ros.org/ros2/ubuntu`), VS Code, Node.js, and Google Chrome. The final line `N: Skipping acquire of configured file 'main/binary-i386/Packages'` is benign — Chrome's apt repo only ships 64-bit packages, not 32-bit. Ubuntu tried to fetch an i386 package list, the server said it has none, and apt moved on. This has no effect on your ROS 2 build.

**Step 3: `sudo rosdep init`**

```text
Wrote /etc/ros/rosdep/sources.list.d/20-default.list
Recommended: please run rosdep update
```

This wrote a small text file listing the GitHub URLs for rosdep's YAML databases. `sudo` is required because `/etc/ros/` is a system-owned directory. You run `sudo rosdep init` **only once per machine** — re-running it on an already-initialized machine simply tells you it's already done.

**Step 4: `rosdep update`**

```bash
Hit https://raw.githubusercontent.com/ros/rosdistro/master/rosdep/base.yaml
Hit https://raw.githubusercontent.com/ros/rosdistro/master/rosdep/python.yaml
...
Query rosdistro index https://raw.githubusercontent.com/ros/rosdistro/master/index-v4.yaml
Skip end-of-life distro "ardent" ... "foxy" ... "galactic" ...
Add distro "humble"
Add distro "jazzy"
Add distro "kilted"
Add distro "lyrical"
Add distro "rolling"
updated cache in /home/abdullah/.ros/rosdep/sources.cache
```

rosdep downloaded all the YAML database files and saved them to `~/.ros/rosdep/sources.cache/`. It skipped 13 end-of-life ROS distributions since there is no point caching dependency data for distros no longer supported. It added 5 active distros: humble (LTS), jazzy (current LTS), kilted, lyrical, and rolling. This command needs internet access and should be run every few weeks to pick up changes in the rosdep database, especially before working with a newly cloned package.

**Step 5: Second rosdep command succeeds:**

```bash
rosdep install --from-paths src --ignore-src -y \
  --skip-keys "fastcdr rti-connext-dds-6.0.1 urdfdom_headers"
#All required rosdeps installed successfully
```

The command changed slightly from the first attempt. The first used `-i` (short for `--ignore-src`) and `--from-path` (singular). The second uses `--from-paths` (plural) and `--ignore-src` (the full flag). rosdep accepts both forms — they are identical. The important new addition is `--skip-keys`.

`--ignore-src` tells rosdep: "if a dependency is already provided by a package I can find in my source paths, don't try to install a system version of it." This prevents rosdep from trying to install the apt package for a library you are already building from source.

`--skip-keys "fastcdr rti-connext-dds-6.0.1 urdfdom_headers"` provides an explicit bypass list. These three packages are skipped because:

* `fastcdr` is a serialization library bundled with Fast DDS middleware, typically compiled from source rather than installed via a rosdep key
* `rti-connext-dds-6.0.1` is RTI Connext DDS, a commercial DDS implementation requiring a license that cannot be auto-installed
* `urdfdom_headers` may not have a resolvable rosdep entry for this Ubuntu/ROS combination

Without `--skip-keys`, rosdep would error on these three names. The `#All required rosdeps installed successfully` line confirms every declared dependency in `turtlesim`'s `package.xml` that was missing is now installed.

---

## 5. `colcon build` Arguments Explained + Build Output Analysis

### `--packages-up-to <pkg_name>`

By default, `colcon build` builds **every** package it finds in `src/`. In a large workspace with 50 packages, a full rebuild can take many minutes. `--packages-up-to` builds only the named package and its full dependency chain, skipping everything unrelated.

```bash
colcon build --packages-up-to turtlesim
# Builds: rclcpp → rcl → rmw → ... → turtlesim
# Skips: every package that is NOT a dependency of turtlesim
```

This differs from `--packages-select`, which builds ONLY the named package and assumes all dependencies are already built elsewhere. `--packages-up-to` is safer for fresh builds because it resolves and builds the complete chain itself.

### `--symlink-install`

Without this flag, colcon **copies** built files from `build/<pkg>/` into `install/<pkg>/`. Every time you change a Python script or a launch file, you must re-run `colcon build` to push the change into `install/`.

With `--symlink-install`, colcon creates **symbolic links** in `install/` that point directly back to the source files in `src/`. For Python packages and configuration files, you can edit in `src/` and run immediately without rebuilding:

```bash
# Without --symlink-install
edit src/my_package/my_package/node.py
colcon build              # REQUIRED before the change takes effect
ros2 run my_package node

# With --symlink-install
edit src/my_package/my_package/node.py
ros2 run my_package node  # change is immediately visible ✓
```

Important limitation: `--symlink-install` only helps **non-compiled** files. C++ source code always requires a recompile regardless of this flag.

### `--event-handlers console_direct+`

colcon normally buffers each package's build output and stores it in the `log/` directory. This is clean when many packages build in parallel. But when debugging a failing build, you want to see raw compiler output in real time on your terminal.

```bash
colcon build --event-handlers console_direct+
# → cmake output, make output, and compiler errors
#   stream directly to your terminal as they happen
```

The `+` suffix means "add this handler on top of the defaults" (as opposed to `-` which removes a handler). The default handlers continue writing to `log/` — `console_direct+` adds your terminal screen as a second destination simultaneously.

### `--executor sequential`

colcon's default behavior builds packages in **parallel** — as many simultaneously as there are available CPU cores. This is fast on powerful machines but can overwhelm constrained hardware by saturating all CPU, RAM, and disk I/O at once.

```bash
colcon build --executor sequential
# → packages build one at a time, in dependency order
# → higher total wall-clock time but stable, predictable resource use
```

With sequential execution, the log output is also cleaner — you see one package's output at a time with no interleaving.

### Build Output Analysis — Your Actual Terminal

```bash
[0.536s] WARNING:colcon.colcon_core.package_selection:Some selected packages
are already built in one or more underlay workspaces:
    'turtlesim' is in: /opt/ros/jazzy
```

This warning appeared at 0.536 seconds, before any package started building. colcon's `colcon-override-check` plugin scanned the underlay and found `turtlesim` already installed in `/opt/ros/jazzy`. You are building an overlay that overrides it. The warning then explains two specific risks:

**Risk 1 (headers):** If `turtlesim`'s overlay version installs header files, other packages that include those headers must search the overlay's include path before the underlay's. Wrong include ordering leads to compiling against old headers while linking against new libraries — silent undefined behavior at runtime.

**Risk 2 (ABI compatibility):** If another underlay package dynamically links against the underlay's `turtlesim` shared library, and your overlay's version has a different API or ABI, runtime crashes can occur when the linker loads the wrong version.

For this tutorial both risks are academic. `turtlesim` is a standalone GUI application that no other package links against. This is why the tutorial proceeds without `--allow-overriding turtlesim`. The warning becomes a real concern only when overriding core libraries like `rclcpp` or shared message packages.

```bash
Starting >>> turtlesim
[Processing: turtlesim]
[Processing: turtlesim]
Finished <<< turtlesim [1min 12s]
Summary: 1 package finished [1min 12s]
```

The tutorial documentation shows this taking 5.49 seconds. Your build took 1 minute 12 seconds — about 13× slower. This is explained by your workspace path:

```bash
/mnt/ubuntu_data/ROS2/ROS-2-Jazzy-Jalisco-Tutorials/01-Beginner-Client-libraries/...
```

The `/mnt/ubuntu_data/` prefix means you are working on a mounted partition, likely an NTFS or exFAT drive accessed through Linux's FUSE translation layer. C++ compilation generates thousands of small file I/O operations — reading headers, writing `.o` object files, updating `.d` dependency tracking files, reading CMake cache entries. These operations are fast on a native ext4 filesystem but slow through a FUSE-mounted filesystem because every file access has extra translation overhead. The compiler itself runs at normal CPU speed; the bottleneck is purely disk I/O latency.

For all future ROS 2 work, cloning and building on your native Linux partition (`~/` in your Linux home, not on a mounted Windows drive) will give you the expected build times and a much more comfortable development experience.

After the build, `ls` confirms the four-directory structure was created:

```bash
build  install  log  src
```

---

## 6. What "Sourcing" Means, and Why a New Terminal Is Essential

### What Sourcing Is

`source` (also written as `.`) is a shell built-in command that executes a script **inside the current shell process** rather than spawning a child process. This distinction is everything: when you run `bash script.sh`, any environment changes happen inside a temporary child process that disappears when the script finishes — your shell is unchanged. When you run `source script.sh`, the changes happen directly in your shell session and persist for the rest of that session.

`setup.bash` is a shell script that modifies environment variables. Sourcing it permanently alters your active shell:

```bash
# Before sourcing:
echo $PATH
# → /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
which ros2
# → ros2 not found

source /opt/ros/jazzy/setup.bash

# After sourcing:
echo $PATH
# → /opt/ros/jazzy/bin:/opt/ros/jazzy/lib/...:... ← ROS paths prepended
which ros2
# → /opt/ros/jazzy/bin/ros2 ✓
echo $AMENT_PREFIX_PATH
# → /opt/ros/jazzy
echo $PYTHONPATH
# → /opt/ros/jazzy/lib/python3.12/site-packages:...
```

"Sourcing a workspace" means: "telling this shell session where ROS packages are installed so that `ros2` commands, Python imports, and library loading all work correctly."

### Why You Must Use a New Terminal to Source the Overlay

**Problem 1: Sourcing an overlay in the terminal where you built:**

When you ran `colcon build` in Terminal 1, you had first sourced `/opt/ros/jazzy/setup.bash`. That set `AMENT_PREFIX_PATH=/opt/ros/jazzy` and similar variables. colcon used that state to find dependencies during the build and recorded it inside the generated `install/setup.bash`.

If you then run `source install/setup.bash` in that same Terminal 1, the overlay's environment stacks on top of the already-modified environment. Every path variable accumulates duplicate entries:

```text
AMENT_PREFIX_PATH=/home/abdullah/ros2_ws/install:/opt/ros/jazzy:/opt/ros/jazzy
#                                                 ↑ first source   ↑ duplicated
```

Duplicate entries are harmless once, but every rebuild and re-source in the same terminal adds another copy. Over time, `PATH` and `AMENT_PREFIX_PATH` grow unboundedly until they exceed the OS limit for environment variable size. This causes cryptic failures like `Argument list too long` when trying to run any command — extremely difficult to debug.

**Problem 2: Building in a terminal where an overlay is already sourced:**

If you source the overlay first and then run `colcon build` in that same terminal, CMake picks up the overlay's already-installed packages from `install/` as dependencies for the current build. This creates a self-referential build where the package being compiled uses its own previous build output as an input. The result can be stale dependency detection, circular include paths, or ABI mismatches that are nearly impossible to reproduce and diagnose.

**The clean rule:**

```text
Terminal 1 (BUILD terminal):
└── source /opt/ros/jazzy/setup.bash    ← underlay only, set once
└── colcon build                         ← build here
└── colcon build                         ← rebuild here after changes
└── never source the overlay here

Terminal 2 (RUN terminal):
└── source /opt/ros/jazzy/setup.bash          ← underlay
└── source ~/ros2_ws/install/local_setup.bash  ← overlay on top
└── ros2 run turtlesim turtlesim_node          ← run here
└── never build here
```

Opening a new terminal guarantees you start from a clean, unmodified environment every time.

---

## 7. `local_setup` vs `setup` — General and Workspace-Scoped

### General Difference

Both files live inside the `install/` directory of a workspace. Both are shell scripts that modify environment variables. The difference is scope:

`setup.bash` activates the workspace AND all underlays the workspace was built against. It is self-contained — sourcing it from any fresh terminal is sufficient to use the workspace.

`local_setup.bash` activates ONLY the packages in this workspace itself. It assumes you have already independently handled the underlay.

### In the Scope of Your Workspace

When colcon built `ros2_ws`, it recorded the underlay environment it detected at build time (specifically the `AMENT_PREFIX_PATH` which included `/opt/ros/jazzy`). This information is embedded into `install/setup.bash`. So these two sequences are exactly equivalent:

```bash
# Option A — using local_setup (explicit chain)
source /opt/ros/jazzy/setup.bash              # activate underlay yourself
source ~/ros2_ws/install/local_setup.bash     # then activate overlay packages only

# Option B — using setup (self-contained)
source ~/ros2_ws/install/setup.bash           # activates underlay + overlay together
```

`setup.bash` internally does: "re-activate `/opt/ros/jazzy`" then "activate my own packages on top." The resulting `AMENT_PREFIX_PATH` is identical in both cases:

```bash
/home/abdullah/ros2_ws/install:/opt/ros/jazzy
```

### Analyzing Your Specific Commands

```bash
mypc:~/ROS-2-Jazzy-Jalisco-Tutorials$ source /opt/ros/jazzy/setup.bash
```

You are in the tutorials root directory and you source Jazzy as the underlay. This sets `AMENT_PREFIX_PATH=/opt/ros/jazzy`, adds Jazzy's executables to `PATH`, and makes all Jazzy Python packages importable via `PYTHONPATH`.

```bash
mypc:...$ cd 01-Beginner-Client-libraries/01-Creating-a-workspace/ros2_ws/
```

You navigate to your workspace root. No environment change — `cd` only modifies `$PWD`, nothing else.

```bash
mypc:.../ros2_ws$ source install/local_setup.bash
```

You add only the packages from `ros2_ws/install/` on top of the already-sourced Jazzy. `AMENT_PREFIX_PATH` becomes:

```bash
/mnt/ubuntu_data/.../ros2_ws/install:/opt/ros/jazzy
```

This works correctly because you had already sourced `/opt/ros/jazzy/setup.bash` in this same terminal. If you had opened a fresh terminal and run only `source install/local_setup.bash` without first sourcing Jazzy, you would have the overlay packages but not the underlay — `ros2` would not be in `PATH` and `import rclpy` would fail with `ModuleNotFoundError`.

The practical guidance: use `local_setup` when you are explicitly managing the sourcing chain yourself (as in the tutorial). Use `setup` when you want a single command that "just works" from any fresh terminal.

---

## 8. How the Overlay Takes Precedence — The PATH Prepending Mechanism

"The overlay gets prepended to the path" describes a concrete, verifiable operating system mechanism. Let's trace exactly what happens.

### How `ros2 run` Finds an Executable

When you run `ros2 run turtlesim turtlesim_node`, the `ros2` command reads `$AMENT_PREFIX_PATH` — the colon-separated list of install prefixes — and looks in each prefix's `lib/turtlesim/` directory for a file named `turtlesim_node`.

```text
AMENT_PREFIX_PATH=/home/abdullah/ros2_ws/install:/opt/ros/jazzy
                   ↑ overlay comes first             ↑ underlay is second
```

`ros2 run` checks in order:

1. `/home/abdullah/ros2_ws/install/lib/turtlesim/turtlesim_node` — FOUND → use this, stop searching
2. `/opt/ros/jazzy/lib/turtlesim/turtlesim_node` — never reached

The overlay's prefix appears first because `source install/local_setup.bash` **prepends** its install path to `AMENT_PREFIX_PATH` rather than appending. This left-side insertion is the mechanism behind "overlay takes precedence."

### The `turtle_frame.cpp` Modification — Tracing Each Step

**Before modification, both binaries say "TurtleSim":**

```text
/opt/ros/jazzy/lib/turtlesim/turtlesim_node       → setWindowTitle("TurtleSim")
~/ros2_ws/install/lib/turtlesim/turtlesim_node    → setWindowTitle("TurtleSim")
```

**You edit `src/ros_tutorials/turtlesim/src/turtle_frame.cpp`:**
Change `setWindowTitle("TurtleSim")` → `setWindowTitle("MyTurtleSim")`

**You rebuild in the build terminal:**

```bash
colcon build
# → recompiles turtle_frame.cpp
# → links new turtlesim_node binary
# → installs into ~/ros2_ws/install/lib/turtlesim/turtlesim_node
```

**State after rebuild:**

```text
/opt/ros/jazzy/lib/turtlesim/turtlesim_node       → "TurtleSim"     ← UNCHANGED
~/ros2_ws/install/lib/turtlesim/turtlesim_node    → "MyTurtleSim"   ← UPDATED
```

**In Terminal 2 (overlay sourced):**

```bash
ros2 run turtlesim turtlesim_node
# AMENT_PREFIX_PATH starts with ~/ros2_ws/install
# → finds overlay binary first
# → title: "MyTurtleSim" ✓
```

**In a fresh Terminal 3 (only underlay sourced):**

```bash
source /opt/ros/jazzy/setup.bash
ros2 run turtlesim turtlesim_node
# AMENT_PREFIX_PATH = /opt/ros/jazzy only
# → finds only the underlay binary
# → title: "TurtleSim" (original, unchanged) ✓
```

This demonstrates the core overlay guarantee: modifying your overlay never modifies the underlay. Both binaries coexist on disk at all times. The sourcing order in each terminal decides which one is used.

---

## 9. Full Commands — All Steps in One Reference Block

```bash
# ─── STEP 1: SOURCE THE UNDERLAY ────────────────────────────────────────────
# In your BUILD terminal (Terminal 1):
source /opt/ros/jazzy/setup.bash

# ─── STEP 2: CREATE THE WORKSPACE ───────────────────────────────────────────
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws/src

# ─── STEP 3: CLONE THE SAMPLE REPO ──────────────────────────────────────────
git clone https://github.com/ros/ros_tutorials.git -b jazzy
# Result: src/ros_tutorials/ with 4 packages.
# Only turtlesim will build — the other 3 contain COLCON_IGNORE files.

# Go back to workspace root:
cd ~/ros2_ws

# ─── STEP 4: RESOLVE DEPENDENCIES (rosdep) ──────────────────────────────────
# One-time machine setup (only needed once ever):
sudo rosdep init
rosdep update

# Resolve and install missing system dependencies:
rosdep install --from-paths src --ignore-src -y --skip-keys "fastcdr rti-connext-dds-6.0.1 urdfdom_headers"
# Expected output: #All required rosdeps installed successfully

# ─── STEP 5: BUILD ──────────────────────────────────────────────────────────
# Standard build (tutorial default):
colcon build

# Build with symlink install (recommended for development):
colcon build --symlink-install

# Build only turtlesim and its dependency chain:
colcon build --packages-up-to turtlesim

# Build one package at a time (for slow hardware or mounted drives):
colcon build --executor sequential

# Build with live terminal output instead of buffered log:
colcon build --event-handlers console_direct+

# Build and skip test compilation (faster):
colcon build --cmake-args -DBUILD_TESTING=0

# Suppress the override warning explicitly:
colcon build --allow-overriding turtlesim

# Verify the four directories were created:
ls ~/ros2_ws
# → build  install  log  src

# ─── STEP 6: SOURCE THE OVERLAY ─────────────────────────────────────────────
# IMPORTANT: Open a NEW terminal (Terminal 2) — never reuse the build terminal.

# Source underlay in the new terminal:
source /opt/ros/jazzy/setup.bash

# Navigate to workspace root:
cd ~/ros2_ws

# Option A — source only overlay packages (requires underlay already sourced above):
source install/local_setup.bash

# Option B — source underlay + overlay together (equivalent to Option A here):
# source install/setup.bash

# ─── STEP 7: RUN THE OVERLAY PACKAGE ────────────────────────────────────────
ros2 run turtlesim turtlesim_node
# → turtlesim window opens from YOUR overlay build

# ─── STEP 8: MODIFY THE OVERLAY ─────────────────────────────────────────────
# Edit in your text editor (path from workspace root):
# ~/ros2_ws/src/ros_tutorials/turtlesim/src/turtle_frame.cpp
# Change: setWindowTitle("TurtleSim")   →   setWindowTitle("MyTurtleSim")
# Save the file.

# Rebuild in Terminal 1 (build terminal):
cd ~/ros2_ws
colcon build --packages-up-to turtlesim

# Re-run in Terminal 2 (run terminal):
ros2 run turtlesim turtlesim_node
# → title bar says "MyTurtleSim" — overlay took precedence ✓

# ─── STEP 9: VERIFY UNDERLAY IS UNCHANGED ───────────────────────────────────
# Open Terminal 3 — fresh, source ONLY the underlay:
source /opt/ros/jazzy/setup.bash
ros2 run turtlesim turtlesim_node
# → title bar says "TurtleSim" — underlay is unmodified ✓

# ─── ROSDEP QUICK REFERENCE ─────────────────────────────────────────────────
rosdep check --from-paths src --ignore-src       # dry-run: see what would be installed
rosdep keys --from-paths src                      # list all dependency keys in src/
rosdep resolve rclcpp                             # see what apt package "rclcpp" maps to
rosdep update                                     # refresh the dependency database

# ─── COLCON_IGNORE QUICK REFERENCE ──────────────────────────────────────────
touch src/my_package/COLCON_IGNORE    # disable a package temporarily
rm src/my_package/COLCON_IGNORE       # re-enable it
```
