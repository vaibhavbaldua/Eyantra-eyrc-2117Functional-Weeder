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

  def channel_reg(robot_channel,navigate_channel) do
    receive do
      {:robot_channel,pid} ->
        send(pid,{:channel,robot_channel})
      {:navigate_channel,pid} ->
        send(pid,{:channel, navigate_channel})
    end
    channel_reg(robot_channel,navigate_channel)
  end

  def start_signal do
    channel = choose_channel(:robot_channel)
    msg = %{"event_id" => 12 ,"sender" => "B", "value" => nil }
    {:task_start,reply} = PhoenixClient.Channel.push(channel,"event_msg",msg)
    if reply == "wait" do
      Process.sleep(500)
      start_signal()
    else
      :ok
    end
  end

  def join_channels(socket) do
    {:ok,_response,robot_channel}=PhoenixClient.Channel.join(socket,"robot:status")
    {:ok,_response,navigate_channel}=PhoenixClient.Channel.join(socket,"navigate_B:robot")
    {:ok,pid} = Task.start_link(fn -> channel_reg(robot_channel,navigate_channel) end)
    Process.register(pid,:channel_reg)
    start_signal
  end

  def connect_server do
    socket_opts=Application.get_env(:task_4c_client_robotb, :phoenix_server_url )
    {:ok, socket} = PhoenixClient.Socket.start_link([url: socket_opts])
    wait_until_connected(socket)
    join_channels(socket)
  end

  def choose_channel(channel_name) do
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

  defp wait_until_connected(socket) do
    if !PhoenixClient.Socket.connected?(socket) do
      Process.sleep(100)
      wait_until_connected(socket)
    end
    if Process.whereis(:weed_reg) == nil do
      {:ok,pid}=Task.start_link(fn -> weed_reg([]) end)
      Process.register(pid,:weed_reg)
    end

  end
  
  

  def all_pos() do
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

  def give_goal_cell(goal) do
    all_pos = all_pos()
    Enum.find(all_pos, fn pos -> pos == goal end)
  end

  def weed_reg(list) do
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



  def obs_detected(robot) do
    %Task4CClientRobotB.Position{x: x, y: y, facing: facing} = robot
    msg = %{"event_id" => 2 ,"sender" => "B",
                "value" => %{"x" => x, "y" => y, "face" => facing }}
    channel = choose_channel(:robot_channel)
    {:obstacle_location,"updated"} = PhoenixClient.Channel.push(channel,"event_msg",msg)
  end

  def get_stop_signal(robot) do
    msg = %{"event_id" => 10 , "sender" => "B" , "value" => nil}
    channel = choose_channel(:robot_channel)
    {:stop_signal,info_map } = PhoenixClient.Channel.push(channel,"event_msg",msg)
    %{"event_id" => 6 ,"sender" => "Server", "value" => %{"B" => duration}} = info_map
    channel = choose_channel(:robot_channel)

    if duration > 0 do
      report_next_move(robot,"stopped")
      msg = %{"event_id" => 7,"sender" => "B", "value" => "nil" }
      {:ok,"recorded"} = PhoenixClient.Channel.push(channel,"event_msg",msg)
    end

    Process.sleep(duration*1000)
    if duration > 0 do
      msg = %{"event_id" => 8,"sender" => "B", "value" => "nil" }
      {:ok,"recorded"} = PhoenixClient.Channel.push(channel,"event_msg",msg)
    end

  end

  def get_start do
    channel=choose_channel(:navigate_channel)
    {:start_B, start} = PhoenixClient.Channel.push(channel,"start_pos_B","Robot_B")
    [x,y,face]=start
    [x,String.to_atom(y),String.to_atom(face)]
  end

  def get_goal do
    channel=choose_channel(:navigate_channel)
    {:current_target_B, current_target_B} = PhoenixClient.Channel.push(channel,"fetch_goal_B", "Robo_B")
    [x,y,string] = current_target_B
    if x == nil do
      [x,y,string]
    else
      [x, String.to_atom(y),string]
    end
  end



  def confirm_goal(goal_type,goal) do
    cell = give_goal_cell(goal)
    channel=choose_channel(:navigate_channel)
    {:ok,"recorded"}=PhoenixClient.Channel.push(channel,"acheived_goal_B", "Destination_confirmation_B")
    channel= choose_channel(:robot_channel)
    num = if goal_type == "weeding" do
      4
    else
      3
    end
    msg =  %{"event_id" => num ,"sender" => "B","value" => cell}
    {:ok,"recorded"}=PhoenixClient.Channel.push(channel,"event_msg", msg)
  end

  def report_next_move(robot,action) do
    channel=choose_channel(:navigate_channel)
    %Task4CClientRobotB.Position{x: x, y: y, facing: facing} = robot
    params=%{"client" => "robot_B", "x" => robot.x, "y" => robot.y, "face" => robot.facing, "action" => action}
    {:move, next_move}=PhoenixClient.Channel.push(channel,"next_action_B",params)

    if next_move == "terminate" do
      Task4CClientRobotB.deposit_stalks(robot)
      pid = self()
      send(:weed_reg,{:give_cells,pid})
      list = receive do
        {:cells,list} ->
          list
      end
      channel = choose_channel(:robot_channel)
      string = List.to_string(list)
      msg = %{"event_id" => 5 ,"sender" => "B", "value" => string}
      {:ok,"recorded"} = PhoenixClient.Channel.push(channel,"event_msg",msg)
      channel = choose_channel(:robot_channel)
      msg = %{"event_id" => 9 ,"sender" => "B", "value" => nil }
      {:ok,"recorded"} = PhoenixClient.Channel.push(channel,"event_msg",msg)
    end
    next_move
  end

  def report_robot_status(robot) do
    Process.sleep(1000)
    channel = choose_channel(:robot_channel)
    %Task4CClientRobotB.Position{x: x, y: y, facing: facing} = robot
    message=%{"event_id" => 1 ,"sender" => "B
    ","value" => %{"x" => x, "y" => y, "face" => facing}}
    {:robot_location,"updated"} = PhoenixClient.Channel.push(channel, "event_msg", message)
    #Process.sleep(500)
    IO.puts("I sent my location : #{x}, #{y}, #{facing}")
  end



  #Task4CClientRobotA.PhoenixSocketClient.report_robot_status(%Task4CClientRobotA.Position{x: 3, y: :d, facing: :south})

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
