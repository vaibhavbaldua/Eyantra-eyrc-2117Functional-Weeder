defmodule Task4CPhoenixServerWeb.RobotChannel do
  @robot_map_y_string_to_num %{"a" => 1, "b" => 2, "c" => 3, "d" => 4, "e" => 5, "f" => 6}

  @robot_map_face_atom_to_string %{:west => "west", :east => "east", :south => "south", :north => "north"}

  @robot_map_face_string_to_img_name %{"south" => "robot_facing_south.png" , "north" => "robot_facing_north.png",
                                      "east" => "robot_facing_east.png", "west" =>"robot_facing_west.png"}

  @robotB_map_face_string_to_img_name %{"south" => "robotB_facing_south.png" , "north" => "robotB_facing_north.png",
                                       "east" => "robotB_facing_east.png", "west" =>"robotB_facing_west.png"}

  @robotA_map_face_string_to_img_name %{"south" => "robotA_facing_south.png" , "north" => "robotA_facing_north.png",
                                       "east" => "robotA_facing_east.png", "west" =>"robotA_facing_west.png"}
  use Phoenix.Channel

  @doc """
  Handler function for any Client joining the channel with topic "robot:status".
  Subscribe to the topic named "obs:update" on the Phoenix Server using Endpoint.
  Reply or Acknowledge with socket PID received from the Client.
  """
  def join("robot:status", _params, socket) do
    #Task4CPhoenixServerWeb.Endpoint.subscribe("robot:update")
    Task4CPhoenixServerWeb.Endpoint.subscribe("obs:update")
    #Phoenix.PubSub.subscribe(Task4CPhoenixServer.PubSub, "robot:goals")
    #:ok = Phoenix.PubSub.subscribe(Task4CPhoenixServer.PubSub, "timer:update")
    socket = assign(socket, :timer_tick, 300)
    {:ok, socket}
  end

  @doc """
  Callback function for messages that are pushed to the channel with "robot:status" topic with an event named "new_msg".
  Receive the message from the Client, parse it to create another Map strictly of this format:
  %{"client" => < "robot_A" or "robot_B" >,  "left" => < left_value >, "bottom" => < bottom_value >, "face" => < face_value > }

  These values should be pixel locations for the robot's image to be displayed on the Dashboard
  corresponding to the various actions of the robot as received from the Client.

  Broadcast the created Map of pixel locations, so that the ArenaLive module can update
  the robot's image and location on the Dashboard as soon as it receives the new data.

  Based on the message from the Client, determine the obstacle's presence in front of the robot
  and return the boolean value in this format {:ok, < true OR false >}.

  If an obstacle is present ahead of the robot, then broadcast the pixel location of the obstacle to be displayed on the Dashboard.
  """

  @doc """
  Handler function to update goal list on the dashboard
  It takes Request in the form of a map %{GoalsA: str_listA, GoalsB: str_listB} where str_listA and str_listB
  are lists containing list of goals for robot A and B respectively left to achieve.
  """
  def handle_info(%{GoalsA: str_listA, GoalsB: str_listB}, socket) do
    socket = assign(socket, :robotA_goals, str_listA )
    socket = assign(socket, :robotB_goals, str_listB )
    {:noreply, socket}
  end


  @doc """
  This function extracts the time values at Which Robots A nad B are to stopped or Killed temporarily before resuming
  to their task.
  It fetches the values from Robot_handle.csv file Provided by the E-yantra Team
  """
  def fetch_timestamps(robot) do
    string=File.read!("Robot_handle.csv")
    list=String.split(string, "\n")
    list = list -- ["Robot,Kill Time,Restart Time"]
    time_stamps = Enum.map(list, fn string ->
      [robot,kill_time,revival_time] = String.split(string, ",")
      [robot,String.to_integer(kill_time),String.to_integer(revival_time)]
     end)
    timestamps_A = Enum.map(time_stamps, fn [robot,kill_time,revival_time] ->
      if robot == "A" do
        %{kill_time => revival_time - kill_time}
      end
    end)
    timestamps_A_kill= Enum.map(time_stamps, fn [robot,kill_time,revival_time] ->
      kill_time=if robot == "A" do

        kill_time
      end
    end)

    timestamps_B = Enum.map(time_stamps, fn [robot,kill_time,revival_time] ->
      if robot == "B" do
        %{kill_time => revival_time - kill_time}
      end
    end)
    timestamps_B_kill= Enum.map(time_stamps, fn [robot,kill_time,revival_time] ->
      if robot == "B" do
        kill_time
      end
    end)
    timestamps_A = Enum.uniq(timestamps_A) -- [nil]
    timestamps_B = Enum.uniq(timestamps_B) -- [nil]

    {a,b}=if robot == "A" do
      {timestamps_A ,timestamps_A_kill}
    else
      {timestamps_B ,timestamps_B_kill}
    end
    {a,b}
  end

  @doc """
  This function sends the stopping signals and its duration to the robot clients
  """

  def give_stop_signal(sender,time) do
    {kill_duration_map,ts} = fetch_timestamps(sender)

    t =Enum.find(ts, fn t ->
      map = Enum.find(kill_duration_map, fn map -> Map.has_key?(map,t) end)
      duration = map[t]
      time >= t and time < t + duration
    end)

    if t != nil do
      map = Enum.find(kill_duration_map, fn map -> Map.has_key?(map,t) end)
      duration = map[t]
      stop_time = t + duration
      duration = stop_time - time
      {sender,duration}
    else
      {sender,0}
    end

  end



  @doc """
  This function identifies event from the msg payload
  There are various events ranging from event_id 0 to event_id 12
  """
  def event_identifier(msg,socket) do
    %{"event_id" => num ,"sender" => sender, "value" => value, "timer" => time } = msg
    reply = cond do
      num == 1 ->
        val_y= @robot_map_y_string_to_num[value["y"]]
        face_img = if sender == "A" do
          @robot_map_face_string_to_img_name[value["face"]]
        else
          @robot_map_face_string_to_img_name[value["face"]]
        end

        data = %{"client" =>msg["sender"], "left" =>(value["x"] - 1)*150,"bottom" =>(val_y - 1)*150 ,"face" => face_img}
        Phoenix.PubSub.broadcast(Task4CPhoenixServer.PubSub,"robot:update",data)
        {:robot_location,"updated"}

      num == 2 ->
        val_y= @robot_map_y_string_to_num[value["y"]]
        {obs_x,obs_y}=obs_position(value["x"],val_y,msg["face"])
        Phoenix.PubSub.broadcast(Task4CPhoenixServer.PubSub,"obs:update",%{:obs_status => true ,:x_pixel => obs_x, :y_pixel => obs_y})
        {:obstacle_location,"updated"}

      num == 3 ->
        {:ok,"recorded"}
      num == 4 ->
        {:ok,"recorded"}
      num == 5 ->
        {:ok,"recorded"}
      num == 7 ->
        {:ok,"recorded"}
      num == 8 ->
        {:ok,"recorded"}
      num == 9 ->
        {:ok,"recorded"}
      num == 10 ->
        {client,duration} = give_stop_signal(sender,300 - time)
        reply=%{"event_id" => 6 ,"sender" => "Server", "value" => %{client => duration}}
        {:stop_signal,reply}
      num == 11 ->
        :ok
      num == 12 ->
        reply = if Process.whereis(:start_loc_holder_A) == nil and Process.whereis(:start_loc_holder_B) == nil do
          "wait"
        else
          "go_ahead"
        end
        {:task_start,reply}
    end
    reply
  end


  @doc """
  Handler function to reply robot clients for various event_ids
  """
  def handle_in("event_msg", message, socket) do
    message = Map.put(message, "timer", socket.assigns[:timer_tick])
    #Task4CPhoenixServerWeb.Endpoint.broadcast_from(self(), "robot:status", "event_msg", message)
    reply = event_identifier(message,socket)
    {:reply, reply, socket}
  end


  """
  This function returns the obstacle position coordinates in form of pixel values it takes robot location and its
  facing direction on the arena.
  """
  defp obs_position(bot_x,bot_y,bot_face) do
    {obs_x,obs_y}= cond do
      bot_face == "east" ->
        {(bot_x + 0.5 - 1)*150,(bot_y - 1)*150}
      bot_face == "west" ->
        {(bot_x - 0.5 - 1 )*150,(bot_y - 1)*150}
      bot_face == "north" ->
        {(bot_x - 1)*150,((bot_y + 0.5)-1)*150}
      true ->
        {(bot_x - 1)*150,((bot_y - 0.5)-1)*150}
    end
    {obs_x,obs_y}
  end



end
