defmodule Task4cPhoenixServerWeb.RobotANavigateChannel do
  use Phoenix.Channel
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5, :f => 6}
  @robot_map_y_num_to_atom %{1 => :a, 2 => :b, 3 => :c, 4 => :d, 5 => :e, 6 => :f}

  @impl true

  @doc """
  Handler function for any Robot Client A joining the channel with topic "navigate_A:robot".
  Reply or Acknowledge with socket PID received from the Client.
  """
  def join("navigate_A:robot", payload, socket) do
    socket = assign(socket, :img_robotA, "RobotA_image_on.png")
    socket = assign(socket, :bottom_robotA, 0)
    socket = assign(socket, :left_robotA, 0)
    {:ok,socket}
  end



  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @doc """
  Handler function to messages pushed from Robot Client A with event named "fetch_goal_A"
  """
  @impl true
  def handle_in("fetch_goal_A", msg, socket) do
    IO.inspect(msg)
    msg=String.to_atom(msg)
    apid=self()
    send(:goal_manager_A,{msg,apid})
    current_target_A = receive do
      {:goal,current_target_A} ->
        current_target_A
    end

    pid = self()
    current_target_A = if current_target_A != [nil,nil] do
      #%{"sender" => sender, "goal" => [x,y]}=msg
      [x,y] = current_target_A
      send(:target_identifier,{:find_type,current_target_A,pid})
      string = receive do
        {:goal_type,string} ->
          string
      end
      [x,y,string]
    else
      [nil,nil,nil]
    end

    {:reply, {:current_target_A , current_target_A}, socket}
  end
  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (robot_goals:lobby).


  @doc """
  Handler function for messages pushed from Robot client A with event name "achieved_goal_A"
  when the robot visits a goal position successfully.
  """
  @impl true
  def handle_in("acheived_goal_A", msg, socket) do
    apid=self()
    msg=String.to_atom(msg)
    send(:goal_manager_A,{msg,apid})
    {:reply,{:ok,"recorded"}, socket}
  end


  @doc """
  handler function for messages pushed from Robot Client A to request clearance for its next move to avoid collision with
  another robot.
  """
  @impl true
  def handle_in("next_action_A", payload, socket) do
     %{"client" => "robot_A", "x" => x, "y" => y,
         "face" => facing, "action" => action} = payload
    next_move = commA(%{x: x, y: String.to_atom(y), facing: String.to_atom(facing)},action)
    IO.inspect(next_move)
    {:reply, {:move, next_move}, socket}
  end


  @doc """
  Handler function to handle messages pushed into the channel with event name "start_pos_A"
  It replies with the starting position for Robot Client A.
  """

  def handle_in("start_pos_A",client,socket) do
    pid=self()
    IO.inspect(client)
    client=String.to_atom(client)
    send(:start_loc_holder_A,{:give_start_pos_Robot_A, :PID,pid})
    start = receive do
      {:start_pos_A,start_A} ->
        start_A
    end
    IO.inspect(start)
    {:reply, {:start_A, start}, socket}
  end

  @doc """
  This function takes arguments `robot` and `action` which robot A's location and its next action which can be "moving"
  "turning", "Halting"(robot has stopped at a location temporarily while waiting for another robot to clear the route)
  "farming"( when the robot was uprooting a weed stalk or dropping a seed object ), "moving" (when the robot is about
  to move to the node ahead)
  """
  def commA(robot,action) do
    apid= self()
    IO.inspect(robot)
    params=cond do
      action == "halting" or action == "stopped" or action == "farming" or action == "turning" ->
        x=robot.x
        y=robot.y
        facing=robot.facing
        {:A_is_gonna_be_at,{x,y,facing},:A_action,action,:A_is_at,{x,y,facing},:A_pid,apid}
      action=="moving" ->
        facing=robot.facing
        [x,y]=cond do
          facing==:north ->
            x=robot.x
            IO.inspect(@robot_map_y_atom_to_num[robot.y])
            y=@robot_map_y_num_to_atom[@robot_map_y_atom_to_num[robot.y]+1]
            [x,y]
          facing==:south ->
            x=robot.x
            y=@robot_map_y_num_to_atom[@robot_map_y_atom_to_num[robot.y]-1]
            [x,y]
          facing==:east ->
            y=robot.y
            x=robot.x+1
            [x,y]
          facing==:west ->
            y=robot.y
            x=robot.x-1
            [x,y]
        end
        {:A_is_gonna_be_at,{x,y,facing},:A_action,
        action,:A_is_at,{robot.x,robot.y,robot.facing},:A_pid,apid}
    end
    send(:interceptor,params)
    action=receive do
      {:signal,action} ->
        action
    end
    action
  end





  # Add authorization logic here as required.

end
