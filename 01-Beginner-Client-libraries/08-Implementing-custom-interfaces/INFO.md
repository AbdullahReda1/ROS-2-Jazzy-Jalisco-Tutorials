
# Implementing Custom Interfaces — Deep Study Notes

## ROS 2 Jazzy Jalisco | Beginner: Client Libraries

---

## 1. Why Put Interfaces and Nodes in the Same Package

Two valid reasons: **convenience** and **tight coupling**. When an interface is only ever used by one package and you don't intend to share it with others, creating a separate interface package adds an extra build step, an extra directory, and an extra dependency declaration for no real benefit. Prototyping and small personal projects fall into this category. The tradeoff is that the interface is now locked inside that package — another package cannot use it without depending on the entire node package, which is bad practice for shared code. Use the same-package approach only when the interface is truly private to that one package.

---

## 2. `ament_cmake_python` — What It Is and How to Add Python Nodes to a cmake Package

`ament_cmake_python` is a cmake module (part of the `ament_cmake` suite) that extends a cmake package to also install Python packages and scripts. It bridges the gap: interfaces can only be defined in cmake packages, but you may want Python nodes alongside them in the same package without creating a second Python package.

The key macros it provides:

| Macro                                                                    | Purpose                                                                                                                   |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| `ament_python_install_package(my_pkg)`                                   | Installs the inner Python package directory (the one with`__init__.py`) into the Python path so `import my_pkg` works     |
| `install(PROGRAMS scripts/my_node.py DESTINATION lib/${PROJECT_NAME})`   | Installs a Python script as a runnable executable findable by`ros2 run`                                                   |

A cmake package with both C++ nodes and Python nodes looks like this in `CMakeLists.txt`:

```cmake
find_package(ament_cmake_python REQUIRED)
find_package(rclpy REQUIRED)

# Install the Python package (inner directory with __init__.py):
ament_python_install_package(${PROJECT_NAME})

# Install individual Python node scripts:
install(PROGRAMS
  scripts/my_python_node.py
  DESTINATION lib/${PROJECT_NAME}
)
```

And `package.xml` adds:

```xml
<depend>rclpy</depend>
<buildtool_depend>ament_cmake_python</buildtool_depend>
```

The Python entry points are NOT registered via `setup.py` here — there is no `setup.py` in a cmake package. Instead the `install(PROGRAMS ...)` call makes the script directly findable by `ros2 run` at the expected `lib/<pkg>/` path.

---

## 3. Why `set(msg_files ...)` and the CMake Reconfigure Notice

```cmake
set(msg_files
  "msg/AddressBook.msg"
)
rosidl_generate_interfaces(${PROJECT_NAME} ${msg_files})
```

CMake has two phases: **configure** (reads CMakeLists.txt, generates build files) and **build** (compiles). CMake only reruns the configure phase when it detects that `CMakeLists.txt` itself changed, or when a file it was explicitly told to watch changed.

If you write `rosidl_generate_interfaces(${PROJECT_NAME} "msg/AddressBook.msg")` with the string literal inline, CMake records the file path as a known input. But when you later add `"msg/NewMessage.msg"` as a new file on disk without editing CMakeLists.txt, CMake has no trigger to reconfigure — it does not scan the `msg/` directory automatically. The new `.msg` file is invisible until you manually touch CMakeLists.txt or delete the build cache.

Using `set(msg_files ...)` doesn't change this behavior directly, but the convention of listing each file explicitly makes it clear that adding a new message requires editing CMakeLists.txt, which then triggers reconfiguration. The notice in the tutorial is reinforcing this mental model: **you must add every new `.msg` file to this list manually** — colcon will not auto-discover new files.

---

## 4. `ament_export_dependencies(rosidl_default_runtime)` — What It Does

```cmake
ament_export_dependencies(rosidl_default_runtime)
```

This tells downstream packages — any other package that does `find_package(more_interfaces)` — that `rosidl_default_runtime` is a transitive dependency they will also need at runtime. Without this line, a consumer package would need to declare `<exec_depend>rosidl_default_runtime</exec_depend>` in its own `package.xml` to make the generated typesupport libraries load correctly at runtime.

This line does **not** link the interfaces and nodes together. That linking happens via `rosidl_get_typesupport_target` + `target_link_libraries` (Section 6). `ament_export_dependencies` is purely about propagating dependency information to downstream cmake consumers.

---

## 5. What Links `.msg` Constants to C++ Code

The `.msg` file defines:

```text
uint8 PHONE_TYPE_HOME=0
uint8 PHONE_TYPE_WORK=1
uint8 PHONE_TYPE_MOBILE=2

uint8 phone_type
```

The rosidl C++ generator reads these lines and emits them as `static constexpr` members inside the generated struct in `address_book.hpp`:

```cpp
struct AddressBook {
  static constexpr uint8_t PHONE_TYPE_HOME   = 0;
  static constexpr uint8_t PHONE_TYPE_WORK   = 1;
  static constexpr uint8_t PHONE_TYPE_MOBILE = 2;

  uint8_t phone_type = 0;
};
```

So `message.PHONE_TYPE_MOBILE` accesses the constant through the instance — this is standard C++, equivalent to `AddressBook::PHONE_TYPE_MOBILE` through the class. The constant and the field `phone_type` are both members of the same struct, which is what ties them together conceptually. The `.msg` format puts them in the same message definition, and the generator faithfully reflects that in the generated struct.

---

## 6. `rosidl_get_typesupport_target` + `target_link_libraries` — How the Link Works and Why `--packages-up-to`

When a package uses interfaces from a **different** package, `ament_target_dependencies(my_node other_interfaces_pkg)` is enough — cmake's imported targets mechanism handles it automatically after `find_package(other_interfaces_pkg)`.

When a package uses interfaces it defines **itself**, the generated typesupport library is built as part of the same cmake project. Its cmake target name is not a standard imported target that `ament_target_dependencies` knows about. `rosidl_get_typesupport_target` retrieves that internal target name:

```cmake
rosidl_get_typesupport_target(cpp_typesupport_target
  ${PROJECT_NAME} rosidl_typesupport_cpp)
```

This sets `cpp_typesupport_target` to something like `more_interfaces__rosidl_typesupport_cpp`. Then:

```cmake
target_link_libraries(publish_address_book "${cpp_typesupport_target}")
```

This tells the linker to link `publish_address_book` against the generated typesupport library so the DDS middleware can serialize and deserialize `AddressBook` messages at runtime.

**Why `--packages-up-to more_interfaces`:** `more_interfaces` depends on `rclcpp`, `rosidl_default_generators`, and their transitive dependencies. `--packages-up-to` builds those upstream packages first in the correct order before building `more_interfaces` itself. This is safer than `--packages-select`, which would skip building dependencies and fail if they weren't already built.

---

## 7. Why `<build_depend>rosidl_tutorials_msgs</build_depend>` Instead of `rosidl_default_generators`

`rosidl_default_generators` is needed when **your package generates interfaces** — it provides the cmake macro and generator scripts that create C++ and Python code from `.msg` files. `more_interfaces` already has that declared.

`rosidl_tutorials_msgs` is an **already-generated interface package** — it is the source of the `Contact` message type being used as a field in `AddressBook.msg`. It is treated the same as any other message dependency like `geometry_msgs` or `std_msgs`: you need it at build time (the generator needs to find `Contact`'s type definition to embed it in `AddressBook`'s generated headers) and at runtime (the typesupport for `Contact` must be loaded when messages are transmitted). Hence `<build_depend>` + `<exec_depend>`, or equivalently just `<depend>`.

`rosidl_default_runtime` is also not needed in the extra depend lines because `more_interfaces` already exports it via `ament_export_dependencies(rosidl_default_runtime)` — it's already in the dependency chain.

---

## 8. The Array Contact Code — New Parts Explained

```cpp
auto msg = std::make_shared<more_interfaces::msg::AddressBook>();
```

`AddressBook` is now defined with `address_book` as a `std::vector<Contact>` field. It is created on the heap as a `shared_ptr` because `publish()` in this version takes a dereferenced object rather than a shared_ptr directly.

```cpp
{
  rosidl_tutorials_msgs::msg::Contact contact;
  contact.first_name = "John";
  contact.phone_type = contact.PHONE_TYPE_MOBILE;
  msg->address_book.push_back(contact);
}
```

The `{}` braces are **anonymous scopes**. Each creates a `Contact` stack object, populates its fields, appends it to the vector with `push_back`, and then the `Contact` goes out of scope and is destroyed. The `push_back` copies the contact into the vector before it is destroyed. Using two separate scopes keeps the two `contact` variables completely isolated — no risk of accidentally reusing a field value from the first contact in the second.

`msg->address_book.push_back(contact)` — `msg` is a `shared_ptr`, so `->` dereferences it to reach the `AddressBook` struct's `address_book` vector field. `push_back` appends a copy of `contact` to the vector.

```cpp
address_book_publisher_->publish(*msg);
```

`msg` is a `shared_ptr<AddressBook>`. `publish()` here expects a `const AddressBook &` — a reference to the actual object, not the smart pointer. `*msg` dereferences the shared pointer to produce that reference. In the simpler version earlier in the tutorial, `message` was a stack object so `publish(message)` worked directly with no dereference needed.

---

## 9. Writing the Subscriber

```cpp
// src/subscribe_address_book.cpp

#include <memory>

#include "rclcpp/rclcpp.hpp"
#include "more_interfaces/msg/address_book.hpp"

class AddressBookSubscriber : public rclcpp::Node
{
public:
  AddressBookSubscriber()
  : Node("address_book_subscriber")
  {
    subscription_ = this->create_subscription<more_interfaces::msg::AddressBook>(
      "address_book",
      10,
      [this](const more_interfaces::msg::AddressBook::SharedPtr msg) {
        RCLCPP_INFO(this->get_logger(),
          "Received contact: %s %s | phone: %s",
          msg->first_name.c_str(),
          msg->last_name.c_str(),
          msg->phone_number.c_str());
      });
  }

private:
  rclcpp::Subscription<more_interfaces::msg::AddressBook>::SharedPtr subscription_;
};

int main(int argc, char * argv[])
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<AddressBookSubscriber>());
  rclcpp::shutdown();
  return 0;
}
```

Add to `CMakeLists.txt` after the existing executable block:

```cmake
add_executable(subscribe_address_book src/subscribe_address_book.cpp)
ament_target_dependencies(subscribe_address_book rclcpp)

rosidl_get_typesupport_target(cpp_typesupport_target
  ${PROJECT_NAME} rosidl_typesupport_cpp)
target_link_libraries(subscribe_address_book "${cpp_typesupport_target}")

install(TARGETS
  publish_address_book
  subscribe_address_book
  DESTINATION lib/${PROJECT_NAME})
```

---

## 10. All Commands and Code — One Block

```bash
#!/usr/bin/env bash
# ─── ROS 2 Jazzy Jalisco ─────────────────────────────────────────────────────
# Tutorial: Implementing Custom Interfaces
# ─────────────────────────────────────────────────────────────────────────────

source /opt/ros/jazzy/setup.bash
cd ~/ros2_ws/src

# ─── CREATE THE PACKAGE ──────────────────────────────────────────────────────
ros2 pkg create --build-type ament_cmake --license Apache-2.0 more_interfaces
mkdir more_interfaces/msg

# ─── CREATE THE MSG FILE ─────────────────────────────────────────────────────
cat > more_interfaces/msg/AddressBook.msg << 'EOF'
uint8 PHONE_TYPE_HOME=0
uint8 PHONE_TYPE_WORK=1
uint8 PHONE_TYPE_MOBILE=2

string first_name
string last_name
string phone_number
uint8 phone_type
EOF

# ─── WRITE package.xml ───────────────────────────────────────────────────────
cat > more_interfaces/package.xml << 'EOF'
<?xml version="1.0"?>
<?xml-model href="http://download.ros.org/schema/package_format3.xsd" schematypens="http://www.w3.org/2001/XMLSchema"?>
<package format="3">
  <name>more_interfaces</name>
  <version>0.0.0</version>
  <description>Custom interface implemented in the same package as its nodes</description>
  <maintainer email="you@email.com">Your Name</maintainer>
  <license>Apache-2.0</license>

  <buildtool_depend>ament_cmake</buildtool_depend>

  <depend>rclcpp</depend>
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

# ─── WRITE THE PUBLISHER SOURCE ──────────────────────────────────────────────
cat > more_interfaces/src/publish_address_book.cpp << 'EOF'
#include <chrono>
#include <memory>

#include "rclcpp/rclcpp.hpp"
#include "more_interfaces/msg/address_book.hpp"

using namespace std::chrono_literals;

class AddressBookPublisher : public rclcpp::Node
{
public:
  AddressBookPublisher()
  : Node("address_book_publisher")
  {
    address_book_publisher_ =
      this->create_publisher<more_interfaces::msg::AddressBook>("address_book", 10);

    auto publish_msg = [this]() -> void {
        auto message = more_interfaces::msg::AddressBook();
        message.first_name = "John";
        message.last_name = "Doe";
        message.phone_number = "1234567890";
        message.phone_type = message.PHONE_TYPE_MOBILE;

        std::cout << "Publishing Contact\nFirst:" << message.first_name <<
          "  Last:" << message.last_name << std::endl;

        this->address_book_publisher_->publish(message);
      };
    timer_ = this->create_wall_timer(1s, publish_msg);
  }

private:
  rclcpp::Publisher<more_interfaces::msg::AddressBook>::SharedPtr address_book_publisher_;
  rclcpp::TimerBase::SharedPtr timer_;
};

int main(int argc, char * argv[])
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<AddressBookPublisher>());
  rclcpp::shutdown();
  return 0;
}
EOF

# ─── WRITE THE SUBSCRIBER SOURCE ─────────────────────────────────────────────
cat > more_interfaces/src/subscribe_address_book.cpp << 'EOF'
#include <memory>

#include "rclcpp/rclcpp.hpp"
#include "more_interfaces/msg/address_book.hpp"

class AddressBookSubscriber : public rclcpp::Node
{
public:
  AddressBookSubscriber()
  : Node("address_book_subscriber")
  {
    subscription_ = this->create_subscription<more_interfaces::msg::AddressBook>(
      "address_book",
      10,
      [this](const more_interfaces::msg::AddressBook::SharedPtr msg) {
        RCLCPP_INFO(this->get_logger(),
          "Received contact: %s %s | phone: %s",
          msg->first_name.c_str(),
          msg->last_name.c_str(),
          msg->phone_number.c_str());
      });
  }

private:
  rclcpp::Subscription<more_interfaces::msg::AddressBook>::SharedPtr subscription_;
};

int main(int argc, char * argv[])
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<AddressBookSubscriber>());
  rclcpp::shutdown();
  return 0;
}
EOF

# ─── WRITE CMakeLists.txt ─────────────────────────────────────────────────────
cat > more_interfaces/CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.8)
project(more_interfaces)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(rosidl_default_generators REQUIRED)

set(msg_files
  "msg/AddressBook.msg"
)

rosidl_generate_interfaces(${PROJECT_NAME}
  ${msg_files}
)

ament_export_dependencies(rosidl_default_runtime)

add_executable(publish_address_book src/publish_address_book.cpp)
ament_target_dependencies(publish_address_book rclcpp)

add_executable(subscribe_address_book src/subscribe_address_book.cpp)
ament_target_dependencies(subscribe_address_book rclcpp)

rosidl_get_typesupport_target(cpp_typesupport_target
  ${PROJECT_NAME} rosidl_typesupport_cpp)

target_link_libraries(publish_address_book "${cpp_typesupport_target}")
target_link_libraries(subscribe_address_book "${cpp_typesupport_target}")

install(TARGETS
  publish_address_book
  subscribe_address_book
  DESTINATION lib/${PROJECT_NAME})

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  set(ament_cmake_copyright_FOUND TRUE)
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

ament_package()
EOF

# ─── BUILD ───────────────────────────────────────────────────────────────────
cd ~/ros2_ws
rosdep install -i --from-path src --rosdistro jazzy -y

# --packages-up-to builds more_interfaces and all its upstream dependencies:
colcon build --packages-up-to more_interfaces

# ─── SOURCE AND RUN ──────────────────────────────────────────────────────────
source install/local_setup.bash

# Terminal 2 — publisher:
ros2 run more_interfaces publish_address_book

# Terminal 3 — subscriber:
source ~/ros2_ws/install/local_setup.bash
ros2 run more_interfaces subscribe_address_book

# Terminal 3 alternative — inspect the topic directly:
ros2 topic echo /address_book
```
