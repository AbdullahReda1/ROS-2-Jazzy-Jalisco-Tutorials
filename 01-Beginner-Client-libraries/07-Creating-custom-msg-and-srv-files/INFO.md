# Creating Custom msg and srv Files — Study Notes

## ROS 2 Jazzy Jalisco | Beginner: Client Libraries

---

## 1. Are `.msg` and `.srv` Just Files ROS Reads?

No — they are **source definitions** that trigger real code generation at build time. When you run `colcon build`, the `rosidl_generate_interfaces` CMake macro reads each `.msg` and `.srv` file and produces actual C++ header files and Python module files on disk.

For `Num.msg` with content `int64 num`, the generator produces:

```text
install/tutorial_interfaces/include/tutorial_interfaces/tutorial_interfaces/msg/num.hpp
install/tutorial_interfaces/local/lib/python3.12/dist-packages/tutorial_interfaces/msg/_num.py
```

The C++ header defines a proper struct with a `num` field. The Python file defines a class with a `num` attribute and all the serialization hooks that DDS needs to transmit it over the network. ROS 2 never interprets the `.msg` file at runtime — by then it is gone, replaced by compiled C++ or importable Python that the DDS middleware knows how to serialize and deserialize. The `.msg` and `.srv` files are only ever read once: at build time by the generator.

---

## 2. Why a Standalone Package, and Why Only `ament_cmake`?

**Standalone because of build ordering.** Any package that uses `tutorial_interfaces/msg/Num` must `find_package(tutorial_interfaces)` and include its generated header or import its generated Python class. That generated code only exists after `tutorial_interfaces` has been built. If you put the `.msg` files inside `cpp_pubsub`, then `cpp_pubsub` would need to build itself before it can find its own interfaces — a circular dependency. A standalone interface package is built first; every consumer package is built after.

**Only `ament_cmake` because code generation is a CMake operation.** `rosidl_generate_interfaces` is a CMake macro — it runs during the CMake configure phase, reads your `.msg`/`.srv` files, and registers custom build targets that invoke the generator scripts. An `ament_python` package never invokes CMake at all; it runs setuptools instead. Setuptools has no way to call `rosidl_generate_interfaces`. So the package hosting interface definitions must be `ament_cmake`, even if all the packages that consume those interfaces are Python packages.

---

## 3. How `.msg` Differentiates a Dependency from a Primitive Type

```text
geometry_msgs/Point center
float64 radius
```

The distinction is the `/` character:

A field written as `package_name/TypeName field_name` uses a **package-qualified type**. The `/` signals that `TypeName` is not a built-in primitive — it is a message type defined in another package (`package_name`). The generator must know about that package to produce valid code, which is why `geometry_msgs` appears in both `DEPENDENCIES geometry_msgs` in CMakeLists.txt and `<depend>geometry_msgs</depend>` in package.xml.

A field written as `primitive_type field_name` with no `/` uses a **built-in IDL primitive**. These are hardcoded into the rosidl type system and require no external package. The full list of built-in primitives includes `bool`, `byte`, `char`, `float32`, `float64`, `int8`, `int16`, `int32`, `int64`, and their unsigned equivalents, plus `string`.

---

## 4. CMakeLists.txt — rosidl Commands and How Generation Works

### The Two Required Packages

```cmake
find_package(rosidl_default_generators REQUIRED)
find_package(geometry_msgs REQUIRED)
```

`rosidl_default_generators` loads the CMake machinery that defines the `rosidl_generate_interfaces` macro. Without this, that macro is undefined and CMake errors immediately. It is a build-time-only tool — it generates code and then its job is done.

`geometry_msgs` is needed because `Sphere.msg` references `geometry_msgs/Point`. The generator needs to locate geometry_msgs' own generated headers to know the memory layout of `Point` so it can embed it correctly into the generated code for `Sphere`. Any package referenced with a `/` in any of your `.msg` files must be added here.

### The Main Generation Command

```cmake
rosidl_generate_interfaces(${PROJECT_NAME}
  "msg/Num.msg"
  "msg/Sphere.msg"
  "srv/AddThreeInts.srv"
  DEPENDENCIES geometry_msgs
)
```

| Part                           | Meaning                                                                         |
| ------------------------------ | ------------------------------------------------------------------------------- |
| `${PROJECT_NAME}`              | The library name — must start with the package name (the note in the tutorial)  |
| `"msg/Num.msg"`                | Path to each interface file, relative to the package root                       |
| `DEPENDENCIES geometry_msgs`   | Packages providing types used inside your interface files                       |

### What the Generator Actually Does

At cmake configure time, `rosidl_generate_interfaces` registers custom build targets. When `make` runs, those targets execute Python generator scripts (the `rosidl_generator_cpp` and `rosidl_generator_py` packages) that:

1. Parse each `.msg`/`.srv` file into an abstract type description
2. Render C++ Jinja2 templates → produce `.hpp` header files
3. Render Python Jinja2 templates → produce `_<type>.py` module files
4. Generate `typesupport` files that teach the DDS middleware how to serialize/deserialize the types

The generated files are written to `build/tutorial_interfaces/rosidl_generator_cpp/` and `rosidl_generator_py/` during the build, then installed to `install/tutorial_interfaces/`.

---

## 5. package.xml — rosidl Tags and What They Do

```xml
<depend>geometry_msgs</depend>
<buildtool_depend>rosidl_default_generators</buildtool_depend>
<exec_depend>rosidl_default_runtime</exec_depend>
<member_of_group>rosidl_interface_packages</member_of_group>
```

| Tag                                                              | When needed     | Why                                                                                                                                                                                                      |
| ---------------------------------------------------------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `<depend>geometry_msgs</depend>`                                 | Build + runtime | Sphere.msg embeds geometry_msgs/Point — needed at build time for generation and at runtime for deserialization                                                                                           |
| `<buildtool_depend>rosidl_default_generators</buildtool_depend>` | Build time only | Provides the cmake macro and generator scripts; not needed at runtime                                                                                                                                    |
| `<exec_depend>rosidl_default_runtime</exec_depend>`              | Runtime only    | Provides the runtime type support libraries that DDS uses to actually transmit the generated types; not needed during code generation                                                                    |
| `<member_of_group>rosidl_interface_packages</member_of_group>`   | Build time      | Registers this package in the`rosidl_interface_packages` group — tells other packages' `find_package` calls that this package provides ROS 2 interfaces rather than regular C++ or Python libraries      |

The `<member_of_group>` tag is what makes `find_package(tutorial_interfaces)` work correctly in consumer packages. Without it, cmake cannot automatically find the generated typesupport libraries that DDS needs.

---

## 6. The `member_of_group` Ordering Error — Why and Fix

The `package.xml` format 3 XSD schema enforces a strict **element ordering**. Once `<member_of_group>` appears, the schema allows only more `<member_of_group>` tags or the `<export>` block to follow. Any dependency tag (`<depend>`, `<test_depend>`, etc.) after `<member_of_group>` violates the schema, producing the error:

```text
Element name 'depend' is invalid.
One of the following is expected: member_of_group or export
```

The tutorial showed the four interface-specific lines together without showing their position in the full file:

```xml
<depend>geometry_msgs</depend>
<buildtool_depend>rosidl_default_generators</buildtool_depend>
<exec_depend>rosidl_default_runtime</exec_depend>
<member_of_group>rosidl_interface_packages</member_of_group>
```

If you insert this block before your `<test_depend>` tags (as the tutorial implies by showing them together), the `<test_depend>` tags that come after `<member_of_group>` violate the schema. The correct order the XSD enforces is:

```text
buildtool_depend  →  depend / exec_depend / build_depend  →  test_depend  →  member_of_group  →  export
```

Your working version is correct — `<member_of_group>` after `<test_depend>` and before `<export>`:

```xml
<buildtool_depend>ament_cmake</buildtool_depend>

<depend>geometry_msgs</depend>
<buildtool_depend>rosidl_default_generators</buildtool_depend>
<exec_depend>rosidl_default_runtime</exec_depend>

<test_depend>ament_lint_auto</test_depend>
<test_depend>ament_lint_common</test_depend>

<member_of_group>rosidl_interface_packages</member_of_group>

<export>
  <build_type>ament_cmake</build_type>
</export>
```

---

## 7. All Commands — One Block

```bash
#!/usr/bin/env bash
# ─── ROS 2 Jazzy Jalisco ─────────────────────────────────────────────────────
# Tutorial: Creating Custom msg and srv Files
# ─────────────────────────────────────────────────────────────────────────────

source /opt/ros/jazzy/setup.bash
cd ~/ros2_ws/src

# ─── RECREATE PREVIOUS TUTORIAL PACKAGES (if not already present) ─────────────

# C++ publisher/subscriber (lesson 4):
ros2 pkg create --build-type ament_cmake --license Apache-2.0 cpp_pubsub

# Python publisher/subscriber (lesson 5):
ros2 pkg create --build-type ament_python --license Apache-2.0 py_pubsub

# C++ service/client (lesson 6):
ros2 pkg create --build-type ament_cmake --license Apache-2.0 cpp_srvcli --dependencies rclcpp tutorial_interfaces

# Python service/client (lesson 7):
ros2 pkg create --build-type ament_python --license Apache-2.0 py_srvcli --dependencies rclpy tutorial_interfaces

# ─── CREATE THE INTERFACE PACKAGE ────────────────────────────────────────────
ros2 pkg create --build-type ament_cmake --license Apache-2.0 tutorial_interfaces

# ─── CREATE msg AND srv DIRECTORIES ──────────────────────────────────────────
cd ~/ros2_ws/src/tutorial_interfaces
mkdir msg srv

# ─── CREATE INTERFACE DEFINITION FILES ───────────────────────────────────────
echo "int64 num" > msg/Num.msg

cat > msg/Sphere.msg << 'EOF'
geometry_msgs/Point center
float64 radius
EOF

cat > srv/AddThreeInts.srv << 'EOF'
int64 a
int64 b
int64 c
---
int64 sum
EOF

# ─── WRITE CMakeLists.txt ─────────────────────────────────────────────────────
cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.8)
project(tutorial_interfaces)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(geometry_msgs REQUIRED)
find_package(rosidl_default_generators REQUIRED)

rosidl_generate_interfaces(${PROJECT_NAME}
  "msg/Num.msg"
  "msg/Sphere.msg"
  "srv/AddThreeInts.srv"
  DEPENDENCIES geometry_msgs
)

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  set(ament_cmake_copyright_FOUND TRUE)
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

ament_package()
EOF

# ─── WRITE package.xml ───────────────────────────────────────────────────────
cat > package.xml << 'EOF'
<?xml version="1.0"?>
<?xml-model href="http://download.ros.org/schema/package_format3.xsd" schematypens="http://www.w3.org/2001/XMLSchema"?>
<package format="3">
  <name>tutorial_interfaces</name>
  <version>0.0.0</version>
  <description>Custom message and service definitions</description>
  <maintainer email="you@email.com">Your Name</maintainer>
  <license>Apache-2.0</license>

  <buildtool_depend>ament_cmake</buildtool_depend>

  <depend>geometry_msgs</depend>
  <buildtool_depend>rosidl_default_generators</buildtool_depend>
  <exec_depend>rosidl_default_runtime</exec_depend>

  <test_depend>ament_lint_auto</test_depend>
  <test_depend>ament_lint_common</test_depend>

  <member_of_group>rosidl_interface_packages</member_of_group>

  <export>
    <build_type>ament_cmake</build_type>
  </export>
</package>
EOF

# ─── BUILD THE INTERFACE PACKAGE ─────────────────────────────────────────────
cd ~/ros2_ws
rosdep install -i --from-path src --rosdistro jazzy -y
colcon build --packages-select tutorial_interfaces

# ─── VERIFY THE GENERATED INTERFACES ─────────────────────────────────────────
source install/setup.bash

ros2 interface show tutorial_interfaces/msg/Num
# Expected: int64 num

ros2 interface show tutorial_interfaces/msg/Sphere
# Expected:
# geometry_msgs/Point center
#         float64 x
#         float64 y
#         float64 z
# float64 radius

ros2 interface show tutorial_interfaces/srv/AddThreeInts
# Expected:
# int64 a
# int64 b
# int64 c
# ---
# int64 sum

# ─── UPDATE CONSUMER PACKAGES TO USE THE NEW INTERFACES ──────────────────────
# After editing cpp_pubsub / py_pubsub / cpp_srvcli / py_srvcli source files
# to use tutorial_interfaces (see tutorial section 7), add to their package.xml:
#
# C++ packages:  <depend>tutorial_interfaces</depend>
# Python packages: <exec_depend>tutorial_interfaces</exec_depend>
#
# Then rebuild each consumer package:
colcon build --packages-select cpp_pubsub
colcon build --packages-select py_pubsub
colcon build --packages-select cpp_srvcli
colcon build --packages-select py_srvcli

# ─── RUN THE TESTS ───────────────────────────────────────────────────────────
# Terminal 2 — service or publisher:
# ros2 run cpp_srvcli server
# ros2 run py_srvcli service

# Terminal 3 — client:
# ros2 run cpp_srvcli client 2 3 1
# ros2 run py_srvcli client 2 3 1
```
