defmodule Task4CClientRobotA.PhoenixSocketClient do

  alias PhoenixClient.{Socket, Channel, Message}

  @doc """
  Connect to the Phoenix Server URL (defined in config.exs) via socket.
  Once ensured that socket is connected, join the channel on the server with topic "robot:status".
  Get the channel's PID in return after joining it.
  NOTE:
  The socket will automatically attempt to connect when it starts.
  If the socket becomes disconnected, it will attempt to reconnect automatically.
  Please note that start_link is not synchronous,
  so you must wait for the socket to become connected before attempting to join a channel.
  Reference to above note: https://github.com/mobileoverlord/phoenix_client#usage
  You may refer: https://github.com/mobileoverlord/phoenix_client/issues/29#issuecomment-660518498
  """

  @doc """
  This function registers channel parameters for robot_channel and navigate_channel
  Another function requests for channel params in reply channel params are sent for the regarding request
  """

  def channel_reg(robot_channel,navigate_channel) do
    receive do
      {:robot_channel,pid} ->
        send(pid,{:channel,robot_channel})
      {:navigate_channel,pid} ->
        send(pid,{:channel, navigate_channel})
    end
    channel_reg(robot_channel,navigate_channel)
  end

  @doc """
  This function waits till the theme run has started after establishing connection with the server
  the server sends start signal when the user presses the start button on the dashboard
  """

  def start_signal do
    channel = choose_channel(:robot_channel)
    msg = %{"event_id" => 12 ,"sender" => "A", "value" => nil }
    {:task_start,reply} = PhoenixClient.Channel.push(channel,"event_msg",msg)
    if reply == "wait" do
      Process.sleep(500)
      start_signal()
    else
      :ok
    end
  end

  @doc """
  This function joins joins the channels `"robot:status"` and   `"navigate_A:robot"` on the server.
  The robot Client joins the concerned channels after connection with the server is established.
  """

  def join_channels(socket) do
    {:ok,_response,robot_channel}=PhoenixClient.Channel.join(socket,"robot:status")
    {:ok,_response,navigate_channel}=PhoenixClient.Channel.join(socket,"navigate_A:robot")
    {:ok,pid} = Task.start_link(fn -> channel_reg(robot_channel,navigate_channel) end)
    Process.register(pid,:channel_reg)
    start_signal
  end

  @doc """
  This function connects the Robot Client to the server. It parses the server url
  from the config file.
  """
  def connect_server do
    socket_opts=Application.get_env(:task_4c_client_robota, :phoenix_server_url )
    {:ok, socket} = PhoenixClient.Socket.start_link([url: socket_opts])
    wait_until_connected(socket)
    join_channels(socket)
  end

  """
  This function returns the channel params for the chosen channel specified by the input argument
  channel_name which is an atom either :robot_channel or :navigate_channel
  """
  defp choose_channel(channel_name) do
    pid = self
    cond do
      channel_name == :robot_channel ->
        send(:channel_reg,{channel_name,pid})
      channel_name == :navigate_channel ->
        send(:channel_reg,{channel_name,pid})
    end
    channel = receive do
      {:channel,channel} ->
        channel
    end
    channel
  end

  @doc """
  Helper function for connect_server/0 function this function does not
  exit until connection with the server is established
  """
  def wait_until_connected(socket) do
    if !PhoenixClient.Socket.connected?(socket) do
      Process.sleep(100)
      wait_until_connected(socket)
    end
    if Process.whereis(:weed_reg) == nil do
      {:ok,pid}=Task.start_link(fn -> weed_reg([]) end)
      Process.register(pid,:weed_reg)
    end
  end


## Returns all possible node coordinates approachable by the alphabot
#  on the arena.
  defp all_pos() do
    range = 1..25
    #IO.inspect(range)
    all_pos=Enum.map(range , fn num ->
      [x_const,y_coord]=cond do
        num < 6 -> [0,:a]
        num > 5 and num < 11 -> [5,:b]
        num > 10 and num < 16 -> [10,:c]
        num > 15 and num < 21 -> [15,:d]
        num > 20 and num <= 25 -> [20,:e]
      end
      [(num + 1) - x_const, y_coord]
    end)
   all_pos
  end

  ## returns the cell number by taking goal position as input.
  defp give_goal_cell(goal) do
    all_pos = all_pos()
    Enum.find(all_pos, fn pos -> pos == goal end)
  end

  ## It receives request from other functions and replies back the type of goal to the concerned function
  defp weed_reg(list) do
    list = receive do
      {:update_reg,cell_num}->
        list = list ++ [cell_num]
        list
      {:give_cells,pid} ->
        send(pid,{:cells,list})
        list
    end
    weed_reg(list)
  end


  @doc """
  This function sends the location of Robot when obstacle is detected infront of the robot.
  """
  def obs_detected(robot) do
    %Task4CClientRobotA.Position{x: x, y: y, facing: facing} = robot
    msg = %{"event_id" => 2 ,"sender" => "A",
                "value" => %{"x" => x, "y" => y, "face" => facing }}
    channel = choose_channel(:robot_channel)
    {:obstacle_location,"updated"} = PhoenixClient.Channel.push(channel,"event_msg",msg)
  end

  @doc """
  This function requests the server continuously to find whether the robot has to stop or not.
  """
  def get_stop_signal(robot) do
    msg = %{"event_id" => 10 , "sender" => "A" , "value" => nil}
    channel = choose_channel(:robot_channel)
    {:stop_signal,info_map } = PhoenixClient.Channel.push(channel,"event_msg",msg)
    %{"event_id" => 6 ,"sender" => "Server", "value" => %{"A" => duration}} = info_map
    channel = choose_channel(:robot_channel)

    if duration > 0 do
      report_next_move(robot,"stopped")
      msg = %{"event_id" => 7,"sender" => "A", "value" => "nil" }
      {:ok,"recorded"} = PhoenixClient.Channel.push(channel,"event_msg",msg)
    end

    Process.sleep(duration*1000)
    if duration > 0 do
      msg = %{"event_id" => 8,"sender" => "A", "value" => "nil" }
      {:ok,"recorded"} = PhoenixClient.Channel.push(channel,"event_msg",msg)
    end

  end

  @doc """
  This function receives the start position from the server for Robot A from the server.
  """
  def get_start do
    channel=choose_channel(:navigate_channel)
    {:start_A, start} = PhoenixClient.Channel.push(channel,"start_pos_A","Robot_A")
    [x,y,face]=start
    [x,String.to_atom(y),String.to_atom(face)]
  end

  @doc """
  This function returns goal location received as a reply from the server.
  """
  def get_goal do
    channel=choose_channel(:navigate_channel)
    {:current_target_A, current_target_A} = PhoenixClient.Channel.push(channel,"fetch_goal_A", "Robo_A")
    [x,y,string] = current_target_A
    if x == nil do
      [x,y,string]
    else
      [x, String.to_atom(y),string]
    end
  end


  @doc """
  This function sends confirmation to the server after achieving a goal location.
  """
  def confirm_goal(goal_type,goal) do
    cell = give_goal_cell(goal)
    channel=choose_channel(:navigate_channel)
    {:ok,"recorded"}=PhoenixClient.Channel.push(channel,"acheived_goal_A", "Destination_confirmation_A")
    channel= choose_channel(:robot_channel)
    num = if goal_type == "weeding" do
      4
    else
      3
    end
    msg =  %{"event_id" => num ,"sender" => "A","value" => cell}
    {:ok,"recorded"}=PhoenixClient.Channel.push(channel,"event_msg", msg)
  end

  @doc """
  This function reports the robot's location and its next action and awaits clearance to carry out the action
  if a possibility of collision arises the server sends a directive accordingly such as to stop temporarily or to
  take an alternate path
  """
  def report_next_move(robot,action) do
    channel=choose_channel(:navigate_channel)
    %Task4CClientRobotB.Position{x: x, y: y, facing: facing} = robot
    params=%{"client" => "robot_A", "x" => robot.x, "y" => robot.y, "face" => robot.facing, "action" => action}
    {:move, next_move}=PhoenixClient.Channel.push(channel,"next_action_A",params)

    if next_move == "terminate" do
      Task4CClientRobotA.deposit_stalks(robot)
      pid = self()
      send(:weed_reg,{:give_cells,pid})
      list = receive do
        {:cells,list} ->
          list
      end
      channel = choose_channel(:robot_channel)
      string = List.to_string(list)
      msg = %{"event_id" => 5 ,"sender" => "A", "value" => string}
      {:ok,"recorded"} = PhoenixClient.Channel.push(channel,"event_msg",msg)
      channel = choose_channel(:robot_channel)
      msg = %{"event_id" => 9 ,"sender" => "A", "value" => nil }
      {:ok,"recorded"} = PhoenixClient.Channel.push(channel,"event_msg",msg)
    end
    next_move
  end


  @doc """
  This function reports the robot's location to the server after every move
  the server receives the message and updates the position of the Robot's coordinates on the Dashboard.
  """

  def report_robot_status(robot) do
    Process.sleep(1000)
    channel = choose_channel(:robot_channel)
    %Task4CClientRobotB.Position{x: x, y: y, facing: facing} = robot
    message=%{"event_id" => 1 ,"sender" => "A",
              "value" => %{"x" => x, "y" => y, "face" => facing}}
    {:robot_location,"updated"} = PhoenixClient.Channel.push(channel, "event_msg", message)
    #Process.sleep(500)
    IO.puts("I sent my location : #{x}, #{y}, #{facing}")
  end




  @doc """
  Send Toy Robot's current status i.e. location (x, y) and facing
  to the channel's PID with topic "robot:status" on Phoenix Server with the event named "new_msg".
  The message to be sent should be a Map strictly of this format:
  %{"client": < "robot_A" or "robot_B" >,  "x": < x_coordinate >, "y": < y_coordinate >, "face": < facing_direction > }
  In return from Phoenix server, receive the boolean value < true OR false > indicating the obstacle's presence
  in this format: {:ok, < true OR false >}.
  Create a tuple of this format: '{:obstacle_presence, < true or false >}' as a return of this function.
  """

end

