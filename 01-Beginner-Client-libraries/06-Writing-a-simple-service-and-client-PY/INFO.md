
# Writing a Simple Service and Client (Python) — Study Notes

## ROS 2 Jazzy Jalisco | Beginner: Client Libraries

---

## 1. Why `<depend>` Appeared Instead of `<exec_depend>`

When you pass `--dependencies rclpy example_interfaces` to `ros2 pkg create`, the tool always inserts `<depend>` — the combined build+exec+export tag — regardless of whether the package is Python or C++. It does not try to be smart about what the dependency is actually needed for.

```xml
<depend>rclpy</depend>
<depend>example_interfaces</depend>
```

`<depend>` is a strict superset of `<exec_depend>`. It declares the dependency as needed at build time, run time, and when other packages build against yours. For a Python package, the build-time half is unused but harmless — rosdep and colcon simply install the package and move on; they do not error when an `<exec_depend>` would have been more precise.

The rule you learned earlier still stands: the *semantically correct* tag for Python is `<exec_depend>`. But when the tool generates it automatically via `--dependencies`, it defaults to the safe superset `<depend>`. Both work. If you care about precision (publishing a package, working on a team), change it manually to `<exec_depend>` after creation.

---

## 2. Python vs C++ — Same Functions, Different Names, Different Behaviors

| Purpose                     | C++                                                | Python                                           | Same name?  |Notes                                       |
| --------------------------- | -------------------------------------------------- | ------------------------------------------------ | ----------- | -------------------------------------------|
| Send request asynchronously | `client->async_send_request(req)`                  | `self.cli.call_async(self.req)`                  | No          | Both return a future immediately           |
| Extract future value        | `result.get()->sum`                                | `future.result().sum`                            | No          | Both block if called before completion     |
| Spin until one future done  | `rclcpp::spin_until_future_complete(node, result)` | `rclpy.spin_until_future_complete(node, future)` | Yes         | Identical behavior                         |
| Check future succeeded      | `FutureReturnCode::SUCCESS` comparison             | No equivalent                                    | N/A         | Python raises exception on failure         |
| Wait for service            | `client->wait_for_service(1s)`                     | `self.cli.wait_for_service(timeout_sec=1.0)`     | Yes         | Same behavior, different arg style         |
| Init                        | `rclcpp::init(argc, argv)`                         | `rclpy.init()`                                   | Same intent | Python reads`sys.argv` internally          |
| Spin forever                | `rclcpp::spin(node)`                               | `rclpy.spin(node)`                               | Yes         | Identical behavior                         |
| Shutdown                    | `rclcpp::shutdown()`                               | `rclpy.shutdown()`                               | Yes         | Identical behavior                         |
| Logger                      | `rclcpp::get_logger("rclcpp")`                     | `self.get_logger()`                              | No          | Python logger is bound to the node         |
| Log info                    | `RCLCPP_INFO(logger, "msg")`                       | `self.get_logger().info("msg")`                  | No          | C++ macro vs Python method call            |
| String to int               | `atoll(argv[1])`                                   | `int(sys.argv[1])`                               | No          | Same purpose                               |

The most important pair to understand is `call_async` and `future.result()`. In C++, `async_send_request` returns a `std::shared_future` and you extract with `.get()`. In Python, `call_async` returns an `rclpy Future` object and you extract with `.result()`. Both futures work the same way conceptually — they hold a pending value that arrives later — but they are different classes with different method names.

---

## 3. `response.sum` Shows `Any` in VS Code — Why

The types ARE real and fully defined. `request.a`, `request.b`, and `response.sum` are all `int64` at runtime, exactly as declared in the `.srv` file. The problem is how the Python code is generated.

ROS 2's interface generator creates Python classes for message types dynamically — the fields are set as instance attributes at runtime, not declared as class-level type annotations. When VS Code's type checker (Pyright) inspects the class definition, it sees no static annotation for `sum`, `a`, or `b`, so it reports `Any` — meaning "I don't know the type statically."

```python
response.sum = request.a + request.b
#         ^^^                ^^^  ^^^
#         Any                Any  Any  ← what VS Code reports
#     (int64 at runtime, but not annotated statically)
```

This is a known limitation of ROS 2's Python interface generation. The types are not wrong or undefined — they are just invisible to the static analysis layer. There are community-maintained stub packages (`ros2-stubs`) that add type annotations for common message types, but coverage is incomplete. For most ROS 2 Python development, `Any` on message fields is accepted and ignored.

---

## 4. Why Not Use `rclpy.spin_until_future_complete` Inside a Callback

The default rclpy executor is **single-threaded**. When you are inside any callback — a timer callback, a subscriber callback, or a service callback — the executor is busy running your code. It cannot process any other network event while your callback has not returned.

If inside a callback you call `rclpy.spin_until_future_complete(node, future)`, you create a deadlock:

```text
Executor is running your_callback()
  └─ your_callback calls spin_until_future_complete(future)
       └─ spin_until_future_complete blocks, waiting for future to complete
            └─ future completes only when executor receives the service response
                 └─ executor cannot receive anything — it is blocked in your_callback
                      └─ DEADLOCK — nothing ever moves forward
```

The fix is either a `MultiThreadedExecutor` with a `ReentrantCallbackGroup`, or restructuring to callback-based async (pass a done-callback to `call_async` instead of blocking).

---

## 5. Other Ways to Write Service and Client — Named and Compared

| Approach                                         | How                                                                              | Sync/Async | Safe in callback    | Deadlock risk                               |
| ------------------------------------------------ | -------------------------------------------------------------------------------- | ---------- | ------------------- | ------------------------------------------- |
| **Async + `spin_until_future_complete`**         | `call_async()` then spin (tutorial method)                                       | Async      | No — see Section 4  | Yes, if used inside a callback              |
| **Sync `call()`**                                | `self.cli.call(req)` blocks until response                                       | Sync       | No                  | Yes — blocks the executor thread entirely   |
| **Callback-based async**                         | `call_async(req, callback=my_cb)` — done-callback fires when response arrives    | Async      | Yes                 | No — executor calls the callback naturally  |

The tutorial method is correct when called from `main()` outside any callback, which is exactly what the code does. The warning exists because beginners sometimes move that spin call into a timer or subscriber callback, where it deadlocks.

Synchronous `call()` is the simplest API but the most dangerous — it blocks the entire thread and is forbidden inside callbacks for the same deadlock reason, plus it blocks all other callbacks on that thread for the entire duration of the service call.

Callback-based async is the safest pattern for any non-trivial node, but it requires restructuring the code to be event-driven rather than sequential.

---

## 6. Python vs C++ — Service and Client File Comparison

| Aspect                | C++ Service                                                                              | Python Service                                                            | C++ Client                                     | Python Client                                       |
| --------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ---------------------------------------------- | --------------------------------------------------- |
| Code structure        | Free`add()` function + `main()`                                                          | Class`MinimalService(Node)`                                               | All inside`main()` — no class                  | Class`MinimalClientAsync(Node)`                     |
| Wait for service      | N/A                                                                                      | N/A                                                                       | `while(!wait_for_service(1s))` in `main()`     | `while not wait_for_service(1.0)` in `__init__`     |
| Create service/client | `node->create_service<Type>(name, &cb)`                                                  | `self.create_service(Type, name, cb)`                                     | `node->create_client<Type>(name)`              | `self.create_client(Type, name)`                    |
| Callback signature    | `void cb(Request::SharedPtr, Response::SharedPtr)` — void, response filled by pointer    | `def cb(self, req, res): return res` — must explicitly return response    | N/A                                            | N/A                                                 |
| Send request          | N/A                                                                                      | N/A                                                                       | `client->async_send_request(req)`              | `self.cli.call_async(self.req)`                     |
| Get result            | N/A                                                                                      | N/A                                                                       | `result.get()->sum`                            | `future.result().sum`                               |
| Spin style            | `rclcpp::spin(node)` — forever                                                           | `rclpy.spin(node)` — forever                                              | `spin_until_future_complete(node, result)`     | `rclpy.spin_until_future_complete(node, future)`    |
| Arg parsing           | `atoll(argv[1])`, `argc != 3` guard                                                      | `int(sys.argv[1])`, no explicit guard                                     | Same                                           | Same                                                |
| Node cleanup          | Implicit — RAII                                                                          | `minimal_client.destroy_node()` explicit                                  | Implicit                                       | Explicit                                            |

The most notable structural difference: in C++, the **server** uses a stateless free function and the **client** uses no class at all. In Python, **both** server and client are classes. Python's `MinimalClientAsync` class is needed because the `while not wait_for_service` loop runs in `__init__`, and `send_request` is a method — the class holds `self.cli` and `self.req` as members. C++ keeps the client state in local variables inside `main()` instead.

---

## 7. All Commands — One Block

```bash
#!/usr/bin/env bash
# ─── ROS 2 Jazzy Jalisco ─────────────────────────────────────────────────────
# Tutorial: Writing a Simple Service and Client (Python)
# ─────────────────────────────────────────────────────────────────────────────

# ─── SOURCE UNDERLAY ─────────────────────────────────────────────────────────
source /opt/ros/jazzy/setup.bash

# ─── CREATE THE PACKAGE ──────────────────────────────────────────────────────
cd ~/ros2_ws/src
ros2 pkg create --build-type ament_python --license Apache-2.0 py_srvcli \
  --dependencies rclpy example_interfaces
# Note: --dependencies inserts <depend> tags; change to <exec_depend> manually
# if you want semantic precision in package.xml

# ─── UPDATE package.xml METADATA ─────────────────────────────────────────────
# Edit ~/ros2_ws/src/py_srvcli/package.xml:
# <description>Python client server tutorial</description>
# <maintainer email="you@email.com">Your Name</maintainer>
# <license>Apache-2.0</license>

# ─── UPDATE setup.py METADATA ────────────────────────────────────────────────
# Edit ~/ros2_ws/src/py_srvcli/setup.py to match package.xml:
# maintainer='Your Name',
# maintainer_email='you@email.com',
# description='Python client server tutorial',
# license='Apache-2.0',

# ─── CREATE THE SERVICE NODE ─────────────────────────────────────────────────
cat > ~/ros2_ws/src/py_srvcli/py_srvcli/service_member_function.py << 'EOF'
from example_interfaces.srv import AddTwoInts

import rclpy
from rclpy.node import Node


class MinimalService(Node):

    def __init__(self):
        super().__init__('minimal_service')
        self.srv = self.create_service(AddTwoInts, 'add_two_ints', self.add_two_ints_callback)

    def add_two_ints_callback(self, request, response):
        response.sum = request.a + request.b
        self.get_logger().info('Incoming request\na: %d b: %d' % (request.a, request.b))
        return response


def main():
    rclpy.init()
    minimal_service = MinimalService()
    rclpy.spin(minimal_service)
    rclpy.shutdown()


if __name__ == '__main__':
    main()
EOF

# ─── CREATE THE CLIENT NODE ───────────────────────────────────────────────────
cat > ~/ros2_ws/src/py_srvcli/py_srvcli/client_member_function.py << 'EOF'
import sys

from example_interfaces.srv import AddTwoInts
import rclpy
from rclpy.node import Node


class MinimalClientAsync(Node):

    def __init__(self):
        super().__init__('minimal_client_async')
        self.cli = self.create_client(AddTwoInts, 'add_two_ints')
        while not self.cli.wait_for_service(timeout_sec=1.0):
            self.get_logger().info('service not available, waiting again...')
        self.req = AddTwoInts.Request()

    def send_request(self, a, b):
        self.req.a = a
        self.req.b = b
        return self.cli.call_async(self.req)


def main():
    rclpy.init()
    minimal_client = MinimalClientAsync()
    future = minimal_client.send_request(int(sys.argv[1]), int(sys.argv[2]))
    rclpy.spin_until_future_complete(minimal_client, future)
    response = future.result()
    minimal_client.get_logger().info(
        'Result of add_two_ints: for %d + %d = %d' %
        (int(sys.argv[1]), int(sys.argv[2]), response.sum))
    minimal_client.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()
EOF

# ─── ADD ENTRY POINTS TO setup.py ────────────────────────────────────────────
# Set entry_points in ~/ros2_ws/src/py_srvcli/setup.py:
# entry_points={
#     'console_scripts': [
#         'service = py_srvcli.service_member_function:main',
#         'client = py_srvcli.client_member_function:main',
#     ],
# },

# ─── RESOLVE DEPENDENCIES ────────────────────────────────────────────────────
cd ~/ros2_ws
rosdep install -i --from-path src --rosdistro jazzy -y

# ─── BUILD ───────────────────────────────────────────────────────────────────
colcon build --packages-select py_srvcli

# ─── SOURCE THE OVERLAY ──────────────────────────────────────────────────────
# Open a NEW terminal:
source /opt/ros/jazzy/setup.bash
cd ~/ros2_ws
source install/setup.bash

# ─── RUN THE SERVICE NODE (Terminal 2) ───────────────────────────────────────
ros2 run py_srvcli service
# Expected: node waits silently for requests

# ─── RUN THE CLIENT NODE (Terminal 3) ────────────────────────────────────────
# Open another new terminal:
source /opt/ros/jazzy/setup.bash
cd ~/ros2_ws
source install/setup.bash
ros2 run py_srvcli client 2 3
# Expected client output:
# [INFO] [minimal_client_async]: Result of add_two_ints: for 2 + 3 = 5
#
# Expected service output (Terminal 2):
# [INFO] [minimal_service]: Incoming request
# a: 2 b: 3

# Press Ctrl+C in the service terminal to stop it.
```
