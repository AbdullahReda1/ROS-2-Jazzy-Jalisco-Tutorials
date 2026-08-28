cmake_minimum_required(VERSION 3.8)
project(more_interfaces)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# find dependencies
find_package(ament_cmake REQUIRED)
find_package(ament_cmake_python REQUIRED)
find_package(rosidl_default_generators REQUIRED)
find_package(rclcpp REQUIRED)
find_package(rclpy REQUIRED)


# Generate the message files for this package, then export the dependencies for other packages to use
set(msg_files "msg/Contact.msg" "msg/AddressBook.msg")

rosidl_generate_interfaces(${PROJECT_NAME} ${msg_files})

ament_export_dependencies(rosidl_default_runtime)


# Generate the executables for the publisher and subscriber nodes then install them
add_executable(publish_contact src/publish_contact.cpp)
ament_target_dependencies(publish_contact rclcpp)

add_executable(subscribe_contact src/subscribe_contact.cpp)
ament_target_dependencies(subscribe_contact rclcpp)

add_executable(publish_address_book src/publish_address_book.cpp)
ament_target_dependencies(publish_address_book rclcpp)

add_executable(subscribe_address_book src/subscribe_address_book.cpp)
ament_target_dependencies(subscribe_address_book rclcpp)

install(TARGETS
  publish_contact
  subscribe_contact
  publish_address_book
  subscribe_address_book
  DESTINATION lib/${PROJECT_NAME})#


# Generate the C++ typesupport target for this package and link it to the executables
rosidl_get_typesupport_target(cpp_typesupport_target ${PROJECT_NAME} rosidl_typesupport_cpp)

target_link_libraries(publish_contact "${cpp_typesupport_target}")
target_link_libraries(subscribe_contact "${cpp_typesupport_target}")

target_link_libraries(publish_address_book "${cpp_typesupport_target}")
target_link_libraries(subscribe_address_book "${cpp_typesupport_target}")


# Generate the Python executables for the publisher and subscriber nodes then install them
ament_python_install_package(scripts)

install(PROGRAMS
  scripts/publish_contact.py
  scripts/subscribe_contact.py
  DESTINATION lib/${PROJECT_NAME}
)


# Add testing dependencies and enable testing
if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  # the following line skips the linter which checks for copyrights
  # comment the line when a copyright and license is added to all source files
  set(ament_cmake_copyright_FOUND TRUE)
  # the following line skips cpplint (only works in a git repo)
  # comment the line when this package is in a git repo and when
  # a copyright and license is added to all source files
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

ament_package()
