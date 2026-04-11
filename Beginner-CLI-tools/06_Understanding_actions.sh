#!/usr/bin/bash

#########################################################
# ROS 2 ACTIONS - PRACTICAL + DEEP EXPLANATION
# -------------------------------------------------------
# Actions = Long-running tasks with:
#   1) Goal     (request)
#   2) Feedback (continuous updates)
#   3) Result   (final response)
#
# Built on:
# - Topics (for feedback & status)
# - Services (for goal/result handling)
#########################################################


##############################
# 1) Setup
##############################

# Start turtlesim node (ACTION SERVER)
gnome-terminal -- bash -c \
"ros2 run turtlesim turtlesim_node; exec bash"

# Start teleop node (ACTION CLIENT)
gnome-terminal -- bash -c \
"ros2 run turtlesim turtle_teleop_key; exec bash"

sleep 2

# 👉 Now:
# /turtlesim      → Action SERVER
# /teleop_turtle  → Action CLIENT


##############################
# 2) Use actions (MANUAL STEP)
##############################

echo "
🎮 MANUAL STEP:

In teleop terminal:

- Press keys: G B V C D E R T
  → send rotation GOALS

- Press F
  → CANCEL current goal

Observe:
- Goal completion
- Goal cancellation
- Goal abortion (when sending new goal before finishing)
"

# 👉 What happens internally:
#
# teleop_turtle → sends GOAL
# turtlesim     → processes + sends FEEDBACK + RESULT


##############################
# 3) ros2 node info (actions)
##############################

echo "📡 Inspecting /turtlesim node:"
ros2 node info /turtlesim
echo

echo "📡 Inspecting /teleop_turtle node:"
ros2 node info /teleop_turtle
echo

# 👉 Key observation:
# /turtlesim → Action Servers:
#   /turtle1/rotate_absolute
#
# /teleop_turtle → Action Clients:
#   same action name


##############################
# 4) ros2 action list
##############################

echo "📡 Listing actions in ROS graph:"
ros2 action list
echo

# 👉 Expect:
# /turtle1/rotate_absolute


##############################
# 4.1) ros2 action list -t
##############################

echo "📡 Listing actions with types:"
ros2 action list -t
echo

# 👉 Type:
# turtlesim/action/RotateAbsolute


##############################
# 5) ros2 action type
##############################

echo "🔍 Action type:"
ros2 action type /turtle1/rotate_absolute
echo


##############################
# 6) ros2 action info
##############################

echo "📊 Action info:"
ros2 action info /turtle1/rotate_absolute
echo

# 👉 Shows:
# - number of clients
# - number of servers


##############################
# 7) ros2 interface show (IDL)
##############################

echo "🧠 Action interface (IDL):"
ros2 interface show turtlesim/action/RotateAbsolute
echo

# 👉 Structure:
#
# GOAL:
#   theta (target angle)
#
# ---
# RESULT:
#   delta (final displacement)
#
# ---
# FEEDBACK:
#   remaining (how much left)


##############################
# 8) ros2 action send_goal
##############################

echo "🚀 Sending action goal (rotate turtle):"

ros2 action send_goal \
/turtle1/rotate_absolute \
turtlesim/action/RotateAbsolute \
"{theta: 1.57}"

echo

# 👉 Behavior:
# - waits for server
# - sends goal
# - prints result


##############################
# 8.1) send goal WITH feedback
##############################

echo "📡 Sending goal with FEEDBACK stream:"

ros2 action send_goal \
/turtle1/rotate_absolute \
turtlesim/action/RotateAbsolute \
"{theta: -1.57}" \
--feedback

echo

# 👉 You will see:
# remaining: ...
# remaining: ...
#
# until:
# Goal finished


##############################
# FINAL UNDERSTANDING
##############################

echo "
🧠 ACTION MODEL:

Client                Server
  │                    │
  ├── Goal ----------> │
  │                    │
  │ <--- ACK --------- │  (Acknowledgment with special ID)
  │                    │
  │ <--- Feedback ---- │  (continuous)
  │                    │
  │ <--- Result ------ │  (final)
"

echo "
📊 COMPARISON:

Topic   → continuous data stream
Service → instant request/response
Action  → long task + feedback + cancel
"