defmodule Task4cPhoenixServerWeb.RobotBNavigateChannel do
  use Phoenix.Channel
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5, :f => 6}
  @robot_map_y_num_to_atom %{1 => :a, 2 => :b, 3 => :c, 4 => :d, 5 => :e, 6 => :f}

  @doc """
  Handler function for any Robot Client B joining the channel with topic "navigate_B:robot".
  Reply or Acknowledge with socket PID received from the Client.
  """
  @impl true
  def join("navigate_B:robot", payload, socket) do
    socket = assign(socket, :img_robotB, "RobotB_image_on.png")
    socket = assign(socket, :bottom_robotB, 750)
    socket = assign(socket, :left_robotB, 750)
    {:ok,socket}
  end



  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (robot_goals:lobby).

  @doc """
  Handler function to messages pushed from Robot Client B with event named "fetch_goal_B"
  """
  @impl true
  def handle_in("fetch_goal_B", msg, socket) do
    apid=self()
    msg=String.to_atom(msg)
    send(:goal_manager_B,{msg,apid})
    current_target_B = receive do
      {:goal,current_target_B} ->
        current_target_B
    end

    pid = self()
    current_target_B = if current_target_B != [nil,nil] do
      [x,y] = current_target_B
      send(:target_identifier,{:find_type,current_target_B,pid})
      string = receive do
        {:goal_type,string} ->
          string
      end
      [x,y,string]
    else
      [nil,nil,nil]
    end

    {:reply, {:current_target_B , current_target_B}, socket}
  end

  @impl true

  @doc """
  Handler function for messages pushed from Robot client B with event name "achieved_goal_B"
  when the robot visits a goal position successfully.
  """
  def handle_in("acheived_goal_B", msg, socket) do
    apid=self()
    msg=String.to_atom(msg)
    send(:goal_manager_B,{msg,apid})
    {:reply,{:ok,"recorded"}, socket}
  end


  @doc """
  handler function for messages pushed from Robot Client B to request clearance for its next move to avoid collision with
  another robot.
  """
  @impl true
  def handle_in("next_action_B", payload, socket) do
    %{"client" => "robot_B", "x" => x, "y" => y,
         "face" => facing, "action" => action} = payload
    move = commB(%{x: x, y: String.to_atom(y), facing: String.to_atom(facing)},action)
    IO.inspect(move)
    {:reply, {:move, move}, socket}
  end


  @doc """
  Handler function to handle messages pushed into the channel with event name "start_pos_B"
  It replies with the starting position for Robot Client B.
  """

  def handle_in("start_pos_B",client,socket) do
    pid=self()
    IO.inspect(client)
    send(:start_loc_holder_B,{:give_start_pos_Robot_B, :PID,pid})
    start = receive do
      {:start_pos_B,start_B} ->
        start_B
    end
    IO.inspect(start)
    {:reply, {:start_B, start}, socket}
  end


  @doc """
  This function takes arguments `robot` and `action` which robot B's location and its next action which can be 
  "turning", "Halting"(robot has stopped at a location temporarily while waiting for another robot to clear the route)
  "farming"( when the robot was uprooting a weed stalk or dropping a seed object ), "moving" (when the robot is about
  to move to the node ahead)
  """
  def commB(robot,action) do
    bpid= self()
    params=cond do
      action == "halting" or action == "stopped" or action == "farming" or action == "turning" ->
        x=robot.x
        y=robot.y
        facing=robot.facing
        {:B_is_gonna_be_at,{x,y,facing},:B_action,action,:B_is_at,{x,y,facing},:B_pid,bpid}

      action=="moving" ->
        facing=robot.facing
        [x,y]=cond do
          facing==:north ->
            x=robot.x
            y= @robot_map_y_num_to_atom[@robot_map_y_atom_to_num[robot.y]+1]
            [x,y]
          facing==:south ->
            x=robot.x
            y= @robot_map_y_num_to_atom[@robot_map_y_atom_to_num[robot.y]-1]
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
        {:B_is_gonna_be_at,{x,y,facing},:B_action,
        action,:B_is_at,{robot.x,robot.y,robot.facing},:B_pid,bpid}
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
