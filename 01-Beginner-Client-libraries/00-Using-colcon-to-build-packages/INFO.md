# Using colcon to Build Packages

## ROS 2 Jazzy Jalisco | Beginner: Client Libraries

---

## 1. What is colcon?

`colcon` stands for **collective construction**. It is a universal build tool meta-layer — it does not compile code itself, but it **orchestrates** the build tools that do (CMake, Python setuptools, etc.) across all packages in a workspace in the correct dependency order.

It is the successor to earlier ROS build tools:

| Old Tool | Problem it Had |
| --- | --- |
| `catkin_make` | Built everything in one CMake invocation — one failure killed all |
| `catkin_make_isolated` | Isolated but slow, no parallelism |
| `catkin_tools` | Better, but ROS 1 only |
| `ament_tools` | Early ROS 2 tool, limited |
| **`colcon`** | Universal, parallel, isolated, extensible via plugins |

### colcon's containing tools (plugins installed with `colcon-common-extensions`)

| Plugin | Role |
| --- | --- |
| `colcon-cmake` | Drives CMake-based packages (`ament_cmake`) |
| `colcon-python-setup-py` | Drives Python packages (`ament_python`) via setuptools |
| `colcon-ros` | Understands `package.xml`, ROS-specific build logic |
| `colcon-recursive-crawl` | Discovers packages recursively inside `src/` |
| `colcon-parallel-executor` | Builds multiple packages simultaneously (default) |
| `colcon-test-result` | Collects and displays test results |
| `colcon-output` | Controls terminal output formatting |
| `colcon-override-check` | Warns when overlay packages shadow underlay ones |
| `colcon-argcomplete` | Provides tab completion for colcon commands |
| `colcon-mixin` | Manages command-line shortcut collections |
| `colcon-cd` | Quick `cd` into a package directory |

---

## 2. What is a ROS 2 Workspace?

A ROS 2 workspace is a **directory with a defined layout** that colcon understands and manages. It groups related packages, their build artifacts, and their runtime environment together.

```text
ros2_ws/          ← workspace root (you run colcon from here)
├── src/          ← your source code lives here
├── build/        ← intermediate build artifacts (auto-generated)
├── install/      ← final installed packages (auto-generated)
└── log/          ← build/test logs (auto-generated)
```

Only `src/` needs to exist before your first build. The other three are created by colcon.

---

## 3. What Each Directory Contains and Why It Exists

### `src/` — Source Space

This is the only directory you **author and manage**. It holds your package source trees, each with a `package.xml` at their root. colcon recursively scans `src/` to discover all packages before doing anything.

```text
src/
└── examples/
    ├── rclcpp/   ← C++ example packages
    └── rclpy/    ← Python example packages
```

### `build/` — Build Space

colcon performs **out-of-source builds** — the intermediate compiler outputs never pollute your source. For each package, a subdirectory is created:

```text
build/
├── .built_by                  ← records which colcon version built this
├── COLCON_IGNORE              ← tells colcon to skip THIS directory during crawl
└── examples_rclcpp_async_client/
    ├── CMakeCache.txt         ← CMake's cached configuration variables
    ├── Makefile               ← generated build rules
    ├── CMakeFiles/            ← CMake internal tracking
    │   └── client_main.dir/
    │       ├── main.cpp.o     ← compiled object file for main.cpp
    │       └── link.txt       ← linker command used to produce the binary
    ├── client_main            ← THE compiled binary (before install)
    ├── colcon_build.rc        ← exit code of the last build (0=success)
    ├── colcon_test.rc         ← exit code of the last test run
    ├── colcon_command_prefix_build.sh     ← environment snapshot at build time
    ├── install_manifest.txt   ← list of all files installed by cmake --install
    ├── symlink_install_manifest.txt ← list of symlinks created by --symlink-install
    ├── CTestTestfile.cmake    ← CTest test registration file
    ├── Testing/               ← raw CTest output (XML results per test run)
    ├── test_results/          ← xUnit XML test reports (used by CI and colcon test-result)
    │   └── examples_rclcpp_async_client/
    │       ├── copyright.xunit.xml
    │       ├── cppcheck.xunit.xml   ← static analysis results
    │       ├── cpplint.xunit.xml    ← style check results
    │       └── uncrustify.xunit.xml ← code formatting check results
    ├── ament_cmake_core/      ← ament CMake machinery files
    ├── ament_cmake_environment_hooks/  ← generates setup.bash/sh/zsh for this pkg
    └── .cmake/api/v1/         ← CMake File API: structured JSON describing build
        ├── query/             ← colcon writes requests here before cmake runs
        └── reply/             ← cmake writes answers here (codemodel, targets, etc.)
```

**Key insight:** The `build/` directory is **not for humans to use directly**. You never run binaries from here. Its sole purpose is to hold what CMake needs between incremental builds so it doesn't recompile everything from scratch.

### `install/` — Install Space

This is where colcon puts the **finished, usable products** of each package. It mirrors what a system installation would look like. After sourcing `install/setup.bash`, your shell can find all executables, libraries, and Python modules from here.

```text
install/
├── setup.bash            ← THE file you source to activate the workspace
├── setup.sh / setup.zsh  ← same, for sh/zsh shells
├── local_setup.bash      ← activates ONLY this workspace (not underlays)
├── _local_setup_util_sh.py ← Python helper that generates environment scripts
└── examples_rclcpp_minimal_publisher/
    ├── lib/
    │   └── examples_rclcpp_minimal_publisher/
    │       ├── publisher_member_function   ← THE executable ros2 run uses
    │       ├── publisher_lambda
    │       └── publisher_not_composable
    └── share/
        ├── ament_index/resource_index/packages/  ← package discovery marker
        └── examples_rclcpp_minimal_publisher/
            ├── package.xml               ← copied for runtime introspection
            ├── environment/path.sh       ← adds lib/ to PATH
            ├── environment/ament_prefix_path.sh  ← registers install prefix
            ├── local_setup.bash          ← per-package environment script
            └── cmake/
                └── examples_rclcpp_minimal_publisherConfig.cmake  ← for find_package()
```

For Python packages (`rclpy` examples), the install space instead contains:

```text
install/examples_rclpy_minimal_publisher/
    ├── lib/
    │   ├── examples_rclpy_minimal_publisher/
    │   │   └── publisher_member_function   ← entry point script
    │   └── python3.12/site-packages/
    │       └── examples-rclpy-minimal-publisher.egg-link  ← points to src/ (symlink install)
    └── share/
        └── examples_rclpy_minimal_publisher/
            └── hook/
                ├── pythonpath.sh    ← adds Python src to PYTHONPATH
                └── pythonpath.dsv   ← machine-readable version of above
```

### `log/` — Log Space

Records every colcon invocation with timestamps. Useful for debugging failed builds.

```text
log/
├── latest_build -> build_2026-05-07_23-12-31/   ← symlink to most recent
└── build_2026-05-07_23-12-31/
    ├── logger_all.log         ← complete output of all packages combined
    ├── events.log             ← timing events: start/finish per package
    └── examples_rclcpp_async_client/
        ├── stdout.log         ← just stdout for this package's build
        ├── stderr.log         ← just stderr (compiler warnings/errors)
        └── command.log        ← exact cmake/make commands colcon ran
```

### `devel/` — Does NOT Exist in ROS 2

In ROS 1 with catkin, `devel/` was a shortcut that let you run code without installing it. It caused all sorts of path contamination bugs. ROS 2 / colcon eliminated it entirely. Instead, `--symlink-install` provides the same "edit and immediately run" benefit cleanly.

---

## 4. What is Sourcing, Why It Matters, and How to Do It

### What Sourcing Is

Your shell starts with no knowledge of ROS. When you run `source install/setup.bash`, you are executing a shell script in your **current shell's process**, which permanently modifies that shell's environment variables for the session:

| Variable Modified | What It Does |
| --- | --- |
| `PATH` | Adds `install/<pkg>/lib/<pkg>/` → lets you run ROS executables |
| `PYTHONPATH` | Adds Python package install paths → lets Python find rclpy modules |
| `LD_LIBRARY_PATH` | Adds shared library paths → lets executables find `.so` files |
| `AMENT_PREFIX_PATH` | Tells ament where all installed packages are |
| `CMAKE_PREFIX_PATH` | Tells CMake where to find installed packages for `find_package()` |

### Why It's Critical

Without sourcing, `ros2 run` cannot find your executables and `import rclpy` will fail. This is not a bug — it is intentional isolation. You can have multiple ROS versions installed; sourcing selects which one is active.

### The Technique

```bash
# Activate the base ROS 2 installation (the underlay):
source /opt/ros/jazzy/setup.bash

# Activate your local workspace (the overlay) — always done AFTER the underlay:
source ~/ros2_ws/install/setup.bash

# To make this permanent for all future terminals, add to ~/.bashrc:
echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
echo "source ~/ros2_ws/install/setup.bash" >> ~/.bashrc
```

**`setup.bash` vs `local_setup.bash`:**

- `setup.bash` sources ALL underlays this workspace was built against, then this workspace. Use this in most cases.
- `local_setup.bash` sources ONLY this workspace. Use when you are chaining workspaces and handling underlay sourcing yourself.

---

## 5. Overlay and Underlay in ROS 2

These terms describe a **layered workspace system**.

```text
/opt/ros/jazzy/          ← UNDERLAY (the base)
        ↓
~/ros2_ws/install/       ← OVERLAY (your workspace, built on top)
```

**Underlay:** A pre-existing, already-sourced ROS environment that provides packages your workspace depends on. In your case, `/opt/ros/jazzy` is the underlay — it contains the full Jazzy distribution. When you ran `source /opt/ros/jazzy/setup.bash` before building, you made jazzy the underlay.

**Overlay:** Your workspace `ros2_ws/`. It is built "on top of" the underlay. Packages in your overlay can use everything from the underlay as dependencies. If your overlay defines a package that also exists in the underlay, your overlay version **takes priority** at runtime.

**Why your build got that warning:**

```text
WARNING: Some selected packages are already built in one or more underlay workspaces:
  'examples_rclcpp_minimal_publisher' is in: /opt/ros/jazzy
```

You cloned the `ros2/examples` repo into `src/`, which contains the same packages already present in `/opt/ros/jazzy`. You are building an overlay that **overrides** those exact packages. colcon is warning you that:

1. Headers from the overlay must be sorted correctly or include conflicts arise
2. If another underlay package depends on `examples_rclcpp_minimal_publisher`, it might get ABI/API incompatibilities at runtime

This is not an error — it is expected for a tutorial where you are deliberately practicing the overlay mechanism.

---

## 6. Building: `--symlink-install` and `--executor sequential`

### `--symlink-install`

Without this flag, colcon **copies** every file from `build/` into `install/`. This means after editing a Python script, you must rebuild to see changes.

With `--symlink-install`, colcon creates **symbolic links** in `install/` that point directly back to files in `src/`. For Python files and other non-compiled resources, you can edit the source and run immediately — no rebuild needed.

```text
# With --symlink-install, this file in install/ is a symlink:
install/examples_rclpy_minimal_publisher/lib/python3.12/site-packages/
    examples-rclpy-minimal-publisher.egg-link   → ../../src/examples/rclpy/.../
```

This works for Python packages and configuration files, but **NOT for compiled C++ code** — C++ must always be recompiled. For `ament_cmake` packages, `--symlink-install` mainly symlinks the install-space setup scripts and share files, not the binaries themselves.

### `--executor sequential`

By default, colcon uses a **parallel executor** — it launches as many package builds simultaneously as there are CPU cores. This is why in your build log you saw multiple `Starting >>>` lines at the same time:

```text
Starting >>> examples_rclcpp_async_client
Starting >>> examples_rclcpp_cbg_executor
Starting >>> examples_rclcpp_minimal_action_client
Starting >>> examples_rclcpp_minimal_action_server
Starting >>> examples_rclcpp_minimal_client
Starting >>> examples_rclcpp_minimal_composition
Starting >>> examples_rclcpp_minimal_publisher
Starting >>> examples_rclcpp_minimal_service
```

Eight packages started simultaneously. This is great for speed but uses all available RAM and CPU. On constrained hardware (Raspberry Pi, etc.), this can freeze the system. `--executor sequential` builds one package at a time:

```bash
colcon build --symlink-install --executor sequential
```

---

## 7. The Build Process — Reading Your Actual CLI Output

Let's walk through exactly what happened when you ran `colcon build --symlink-install`.

### Phase 1: Package Discovery

colcon crawled `src/` recursively, found `package.xml` files, read their `<depend>` tags, and computed a dependency graph to determine a valid build order.

### Phase 2: Override Warning

```text
WARNING: Some selected packages are already built in one or more underlay workspaces:
  'examples_rclcpp_minimal_publisher' is in: /opt/ros/jazzy
  ...
```

colcon detected 16 packages in your `src/` that already exist in `/opt/ros/jazzy`. This is the overlay-overriding-underlay situation. colcon warned but did not stop — the override is intentional.

### Phase 3: Parallel Builds

colcon launched 8 packages simultaneously (your machine's parallelism limit):

```text
Starting >>> examples_rclcpp_async_client       ← C++ async service client
Starting >>> examples_rclcpp_cbg_executor        ← C++ callback group executor demo
Starting >>> examples_rclcpp_minimal_action_client
Starting >>> examples_rclcpp_minimal_action_server
Starting >>> examples_rclcpp_minimal_client
Starting >>> examples_rclcpp_minimal_composition
Starting >>> examples_rclcpp_minimal_publisher
Starting >>> examples_rclcpp_minimal_service
```

For each `ament_cmake` package, colcon:

1. Ran `cmake` in `build/<pkg>/` to configure (read CMakeLists.txt, find dependencies)
2. Ran `make -j<N>` to compile (`.cpp` → `.o` → binary)
3. Ran `cmake --install` to copy/symlink files to `install/<pkg>/`

### Phase 4: Wave 2 — Packages with Dependencies

After some of those finished (~7 seconds), the next wave started:

```text
Finished <<< examples_rclcpp_async_client [6.92s]
Finished <<< examples_rclcpp_minimal_client [6.96s]
Starting >>> examples_rclcpp_minimal_subscriber   ← started only after its deps finished
Starting >>> examples_rclcpp_minimal_timer
```

### Phase 5: Python Packages

Python packages (`rclpy`) are much faster — they don't compile:

```text
Starting >>> examples_rclpy_executors             ← ~11s (includes lint tests)
Starting >>> examples_rclpy_minimal_action_client
Finished <<< examples_rclpy_minimal_publisher [7.24s]
```

For `ament_python` packages, colcon ran `python3 setup.py develop` (or `pip install -e`) to register the package and create entry point scripts.

### Phase 6: Summary

```text
Summary: 22 packages finished [24.6s]
```

22 packages, 24.6 seconds total wall-clock time. Because of parallelism, the actual CPU time was much higher, but you only waited 24 seconds.

---

## 8. Every File Type in Your Workspace Explained

### In `build/<pkg>/` (ament_cmake packages)

| File/Dir | Type | Purpose |
| --- | --- | --- |
| `CMakeCache.txt` | CMake cache | Stores all cmake variable values; delete to force full reconfigure |
| `Makefile` | GNU Makefile | Generated by cmake; `make` uses this to compile |
| `CMakeFiles/` | CMake internals | Dependency tracking, compiler detection, per-target build rules |
| `*.cpp.o` | Object file | Compiled but not yet linked C++ translation unit |
| `*.cpp.o.d` | Dependency file | Lists which headers the .o depends on (for incremental rebuild) |
| `link.txt` | Link command | The exact `g++` command used to link the final binary |
| `client_main` (no extension) | ELF binary | Compiled executable, before being installed to `install/` |
| `CMakeCache.txt` | CMake cache | All variables from cmake configure step |
| `.cmake/api/v1/reply/*.json` | CMake File API | Structured JSON describing the build: targets, files, compiler flags |
| `colcon_build.rc` | Return code | `0` = build succeeded, non-zero = failed |
| `colcon_test.rc` | Return code | `0` = all tests passed |
| `colcon_command_prefix_build.sh` | Env snapshot | The environment variables active when colcon ran cmake |
| `install_manifest.txt` | Install record | List of every file cmake installed to `install/` |
| `symlink_install_manifest.txt` | Symlink record | List of symlinks created by `--symlink-install` |
| `CTestTestfile.cmake` | CTest config | Registers which test executables CTest should run |
| `Testing/*/Test.xml` | CTest raw output | Raw XML output from each CTest run |
| `test_results/*.xunit.xml` | xUnit reports | Structured test results; colcon reads these for pass/fail summary |
| `ament_cmake_core/*.cmake` | ament cmake | Package config files used by other packages' `find_package()` |
| `ament_cmake_environment_hooks/local_setup.*` | Env hooks | Per-package environment scripts; aggregated into workspace `setup.bash` |
| `ament_cmake_index/share/ament_index/` | ament index | Key-value store for package discovery at runtime |
| `*.stamp` files | Change detection | Colcon uses these to detect if source files changed since last build |
| `AMENT_IGNORE` | Skip marker | Tells ament to ignore this directory during package discovery |
| `COLCON_IGNORE` | Skip marker | Tells colcon to skip this directory during package crawl |

### In `build/<pkg>/` (ament_python packages)

| File/Dir | Purpose |
| --- | --- |
| `colcon_command_prefix_setup_py.sh` | Env for running setup.py |
| `*.egg-info/` | Python package metadata (name, version, entry points, deps) |
| `*.egg-info/entry_points.txt` | Maps command names to Python functions (e.g., `publisher_member_function = pkg.module:main`) |
| `prefix_override/sitecustomize.py` | Injected at Python startup to set up the overlay PYTHONPATH correctly |
| `pytest.xml` | pytest test results |
| `.pytest_cache/` | pytest caching for incremental test runs |
| `setup.py` / `setup.cfg` | Python package build definition |
| `resource/<pkg_name>` | ament marker file; presence indicates the package is installed |

### In `install/<pkg>/`

| File/Dir | Purpose |
| --- | --- |
| `lib/<pkg>/<binary>` | Runnable executables — this is what `ros2 run <pkg> <binary>` finds |
| `lib/<pkg>/lib*.so` | Shared libraries (`.so` = Linux shared object, like Windows `.dll`) |
| `share/<pkg>/package.xml` | Package metadata, copied for runtime introspection |
| `share/ament_index/resource_index/packages/<pkg>` | Empty marker file; ament's package registry works by file presence |
| `share/<pkg>/environment/path.sh` | Adds `lib/<pkg>/` to `PATH` when sourced |
| `share/<pkg>/environment/ament_prefix_path.sh` | Adds this install prefix to `AMENT_PREFIX_PATH` |
| `share/<pkg>/hook/cmake_prefix_path.sh` | Adds to `CMAKE_PREFIX_PATH` for dependent packages |
| `share/<pkg>/hook/ld_library_path_lib.sh` | Adds `lib/<pkg>/` to `LD_LIBRARY_PATH` (for shared libs) |
| `share/<pkg>/hook/pythonpath.sh` | Adds Python src dir to `PYTHONPATH` (Python packages) |
| `share/<pkg>/local_setup.bash` | Activates just this one package's environment |
| `share/<pkg>/package.bash/.sh/.zsh` | Shell-specific per-package activation scripts |
| `*.dsv` files | **Dot-Separated Value** format: machine-readable version of the `.sh` env hooks, used to generate shell-specific scripts |
| `*Config.cmake` | CMake package config — allows other packages to do `find_package(examples_rclcpp_minimal_publisher)` |
| `*Config-version.cmake` | Version compatibility checker for `find_package()` |
| `python3.12/site-packages/*.egg-link` | Symlink install pointer: tells Python to look in the src directory for this package |

---

## 9. Test Output Analysis

### First Test Run (after first build)

```text
Summary: 22 packages finished [24.6s]
```

All 22 packages built and tested cleanly.

### Second Test Run

```text
Summary: 22 packages finished [59.9s]
  1 package had stderr output: launch_testing_examples
```

The second run took 59.9s (vs 24.6s). This is because `colcon test` ran the **actual test suites** (pytest, ament_lint, etc.) which take longer than building.

The `launch_testing_examples` stderr output:

```text
Warning: This process (pid=24755) is multi-threaded, use of fork() may lead to deadlocks in the child.
```

This is a harmless Python warning — pytest uses `fork()` internally in a multi-threaded environment (because ROS 2's rclpy uses threads). It is not a test failure. All tests passed; it was just a warning printed to stderr, which colcon reports.

---

## 10. Demo Output Analysis

### Publisher side:-

```text
[INFO] [1778260276.160995603] [minimal_publisher]: Publishing: 'Hello, world! 0'
[INFO] [1778260276.661023373] [minimal_publisher]: Publishing: 'Hello, world! 1'
```

Breaking down the log format:

- `[INFO]` — severity level (DEBUG < INFO < WARN < ERROR < FATAL)
- `[1778260276.160995603]` — Unix timestamp in nanoseconds: May 8, 2026, ~23:11 UTC
- `[minimal_publisher]` — the node name (set in the C++ source via `Node("minimal_publisher")`)
- Message published every **500ms** (0.661 - 0.161 = 0.500s) — the timer callback period

### Subscriber side:-

```text
[INFO] [1778260276.161328027] [minimal_subscriber]: I heard: 'Hello, world! 0'
```

- Timestamp `1778260276.161328027` vs publisher's `1778260276.160995603`
- Difference: **0.000332 seconds = 332 microseconds** — that is the end-to-end DDS latency on localhost
- Numbers match perfectly (0, 1, 2...) — no messages dropped on localhost loopback
- Both processes were stopped with `Ctrl+Z` (sent `SIGTSTP`, which suspends rather than kills — note `[1]+ Stopped`, not `Killed`)

### What this demonstrates:-

The publisher and subscriber are **independent OS processes** communicating over DDS (Data Distribution Service) middleware on the `/chatter` topic (in this case the default topic used by the minimal examples). They have no shared memory — they are truly distributed, just running on the same machine. This is the core of ROS 2's architecture.

---

## 11. How colcon Uses `package.xml`

`package.xml` is the **identity and dependency declaration** of every ROS 2 package. colcon reads it before doing anything else. It is the contract between your package and the build system.

```xml
<?xml version="1.0"?>
<package format="3">
  <name>examples_rclcpp_minimal_publisher</name>
  <version>0.20.0</version>
  <description>Minimal publisher examples</description>
  <maintainer email="...">..</maintainer>
  <license>Apache-2.0</license>

  <buildtool_depend>ament_cmake</buildtool_depend>  <!-- which build system to use -->

  <depend>rclcpp</depend>                           <!-- needed at build AND runtime -->
  <build_depend>some_msgs</build_depend>            <!-- needed only at build time -->
  <exec_depend>rclcpp</exec_depend>                 <!-- needed only at runtime -->

  <test_depend>ament_lint_auto</test_depend>
  <test_depend>ament_cmake_gtest</test_depend>

  <export>
    <build_type>ament_cmake</build_type>            <!-- tells colcon which plugin to use -->
  </export>
</package>
```

**What colcon does with it:**

1. **Reads `<name>`** → creates `build/<name>/` and `install/<name>/`
2. **Reads `<buildtool_depend>`** and `<export><build_type>`** → selects plugin (`colcon-cmake` or `colcon-python-setup-py`)
3. **Reads all `<*_depend>` tags** → constructs the dependency graph, determines build order
4. **Reads `<version>`** → puts into generated `*Config-version.cmake` for downstream `find_package()` version checks

---

## 12. `ament_cmake` vs `ament_python`

These are the two **build types** colcon supports for ROS 2.

### `ament_cmake` — For C++ Packages

Used for packages like `examples_rclcpp_minimal_publisher`.

```text
package.xml → <build_type>ament_cmake</build_type>
CMakeLists.txt → the actual build instructions
```

Build flow:

```text
colcon → cmake -S src/ -B build/pkg/ → make → cmake --install
```

Key CMakeLists.txt pattern:

```cmake
cmake_minimum_required(VERSION 3.8)
project(examples_rclcpp_minimal_publisher)

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)

add_executable(publisher_member_function src/publisher_member_function.cpp)
ament_target_dependencies(publisher_member_function rclcpp)

install(TARGETS publisher_member_function
  DESTINATION lib/${PROJECT_NAME})

ament_package()
```

What you see in `install/`: compiled binaries in `lib/examples_rclcpp_minimal_publisher/`.

### `ament_python` — For Python Packages

Used for packages like `examples_rclpy_minimal_publisher`.

```text
package.xml → <build_type>ament_python</build_type>
setup.py + setup.cfg → the actual build instructions
```

Build flow:

```text
colcon → python3 setup.py develop → register entry points
```

Key `setup.py` pattern:

```python
from setuptools import setup

setup(
    name='examples_rclpy_minimal_publisher',
    version='0.20.0',
    packages=['examples_rclpy_minimal_publisher'],
    install_requires=['setuptools'],
    entry_points={
        'console_scripts': [
            'publisher_member_function = examples_rclpy_minimal_publisher.publisher_member_function:main',
        ],
    },
)
```

What you see in `install/`: Python source pointed to by egg-links, entry-point wrapper scripts in `lib/examples_rclpy_minimal_publisher/`.

**Comparison:**

| Aspect | `ament_cmake` | `ament_python` |
| --- | --- | --- |
| Language | C++ | Python |
| Build tool | CMake + Make | setuptools |
| Compile step? | Yes (`.cpp → .o → binary`) | No |
| Build speed | Slower | Fast |
| `--symlink-install` benefit | Only non-compiled files | All Python source files |
| Config file | `CMakeLists.txt` | `setup.py` + `setup.cfg` |

---

## 13. What is `colcon_cd`?

`colcon_cd` is a **shell function** (not a binary) that changes your terminal's current working directory to a package's source directory.

```bash
colcon_cd examples_rclcpp_minimal_publisher
# equivalent to: cd ~/ros2_ws/src/examples/rclcpp/minimal_publisher/
```

**Critically: it does NOT change the build environment.** It only changes your working directory (`$PWD`). The active ROS environment (the sourced workspace, `AMENT_PREFIX_PATH`, etc.) is completely unaffected. It is purely a navigation convenience.

It works by reading the `_colcon_cd_root` environment variable to know where to look:

```bash
export _colcon_cd_root=/opt/ros/jazzy/   # set in ~/.bashrc
```

Setup (add to `~/.bashrc`):

```bash
source /usr/share/colcon_cd/function/colcon_cd.sh
export _colcon_cd_root=/opt/ros/jazzy/
```

---

## 14. Analysis of `pip show colcon-argcomplete`

```text
$ pip show colcon-argcomplete
Name: colcon-argcomplete
Version: 0.3.3
Summary: Completion for colcon command lines using argcomplete.
Location: /usr/lib/python3/dist-packages
Requires: argcomplete, colcon-core
Required-by: colcon-common-extensions
```

**`argcomplete`** is a Python library that hooks into bash's tab-completion system. It works by registering a completion handler that Python scripts can use.

**`colcon-argcomplete`** wraps argcomplete specifically for colcon: when you type `colcon build --<TAB>`, it calls back into colcon's argument parser and returns valid options.

**`Location: /usr/lib/python3/dist-packages`** — installed system-wide via `apt` (as part of `python3-colcon-common-extensions`), not via pip into a virtualenv.

**`Required-by: colcon-common-extensions`** — it was installed as a dependency of the meta-package `colcon-common-extensions` which you installed with `apt install python3-colcon-common-extensions`.

To activate tab completion, add to `~/.bashrc`:

```bash
eval "$(register-python-argcomplete3 colcon)"
```

Or use the colcon-provided script:

```bash
source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash
```

---

## 15. Colcon Mixins

Mixins are **named collections of command-line arguments** stored in a YAML file. They exist because some common flags are long and hard to remember.

### Without mixins:-

```bash
colcon build --cmake-args -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

### With mixins:-

```bash
colcon build --mixin debug compile-commands
```

### Setup:-

```bash
# Add the default mixin repository:
colcon mixin add default https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml

# Download/update the mixin definitions:
colcon mixin update default
```

### Common mixins in the default repository:-

| Mixin name | Expands to |
| --- | --- |
| `debug` | `--cmake-args -DCMAKE_BUILD_TYPE=Debug` |
| `release` | `--cmake-args -DCMAKE_BUILD_TYPE=Release` |
| `compile-commands` | `--cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` |
| `ccache` | Adds ccache compiler wrapper for faster rebuilds |
| `coverage-gcc` | Adds GCC coverage flags |

Mixins are stored locally after `colcon mixin update` and can be listed with `colcon mixin show`.

---

## 16. All Bash Commands — Reference Block

```bash
# ─── INSTALL ────────────────────────────────────────────────────────────────
sudo apt install python3-colcon-common-extensions

# ─── WORKSPACE SETUP ────────────────────────────────────────────────────────
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws

# Clone the example packages:
git clone https://github.com/ros2/examples src/examples -b jazzy

# ─── SOURCE UNDERLAY BEFORE BUILDING ────────────────────────────────────────
source /opt/ros/jazzy/setup.bash

# ─── BUILD ──────────────────────────────────────────────────────────────────
# Standard build with symlink install (recommended for development):
colcon build --symlink-install

# Build one package at a time (for low-resource machines):
colcon build --symlink-install --executor sequential

# Build and skip tests in CMake packages:
colcon build --symlink-install --cmake-args -DBUILD_TESTING=0

# Override underlay packages (suppress warning, use with care):
colcon build --symlink-install --allow-overriding <pkg1> <pkg2>

# Build only specific packages:
colcon build --symlink-install --packages-select examples_rclcpp_minimal_publisher

# ─── TEST ───────────────────────────────────────────────────────────────────
colcon test

# Test only one package:
colcon test --packages-select examples_rclcpp_minimal_publisher

# Run a specific test by name:
colcon test --packages-select YOUR_PKG_NAME --ctest-args -R YOUR_TEST_IN_PKG

# View test results summary:
colcon test-result --verbose

# ─── SOURCE OVERLAY AFTER BUILDING ──────────────────────────────────────────
source install/setup.bash

# ─── RUN DEMO ───────────────────────────────────────────────────────────────
# Terminal 1 — subscriber:
ros2 run examples_rclcpp_minimal_subscriber subscriber_member_function

# Terminal 2 — publisher (source setup first if new terminal):
source install/setup.bash
ros2 run examples_rclcpp_minimal_publisher publisher_member_function

# ─── COLCON_CD SETUP (add to ~/.bashrc) ─────────────────────────────────────
echo "source /usr/share/colcon_cd/function/colcon_cd.sh" >> ~/.bashrc
echo "export _colcon_cd_root=/opt/ros/jazzy/" >> ~/.bashrc
source ~/.bashrc

# Usage — navigate to a package source dir:
colcon_cd examples_rclcpp_minimal_publisher

# ─── TAB COMPLETION SETUP (add to ~/.bashrc) ────────────────────────────────
echo "source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash" >> ~/.bashrc
source ~/.bashrc

# ─── MIXINS ─────────────────────────────────────────────────────────────────
colcon mixin add default https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml
colcon mixin update default

# Use a mixin:
colcon build --mixin debug

# List available mixins:
colcon mixin show

# ─── TIPS ───────────────────────────────────────────────────────────────────
# Ignore a package during build — create an empty file in its directory:
touch src/examples/rclcpp/some_package/COLCON_IGNORE

# Check what colcon-argcomplete installed:
pip show colcon-argcomplete

# Verify the installed executables are in install/:
find install/examples_rclcpp_minimal_publisher/lib -type f -executable
```
