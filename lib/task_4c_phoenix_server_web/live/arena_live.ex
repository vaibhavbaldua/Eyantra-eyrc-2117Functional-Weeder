defmodule Task4CPhoenixServerWeb.ArenaLive do
  use Task4CPhoenixServerWeb,:live_view
  require Logger
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5, :f => 6}




  @doc """
  Mount the Dashboard when this module is called with request
  for the Arena view from the client like browser.
  Subscribe to the "robot:update" topic using Endpoint.
  Subscribe to the "timer:update" topic as PubSub.
  Assign default values to the variables which will be updated
  when new data arrives from the RobotChannel module.
  """
  def mount(_params, _session, socket) do

    Task4CPhoenixServerWeb.Endpoint.subscribe("robot:update")
    Task4CPhoenixServerWeb.Endpoint.subscribe("obs:update")
    :ok = Phoenix.PubSub.subscribe(Task4CPhoenixServer.PubSub, "timer:update")
    :ok = Phoenix.PubSub.subscribe(Task4CPhoenixServer.PubSub, "robot:goals")


    socket = assign(socket, :img_robotA, "RobotA_image_off.png")
    socket = assign(socket, :bottom_robotA, 0)
    socket = assign(socket, :left_robotA, 0)
    socket = assign(socket, :robotA_start, "")
    socket = assign(socket, :robotA_goals, [])

    socket = assign(socket, :img_robotB, "RobotB_image_off.png")
    socket = assign(socket, :bottom_robotB, 750)
    socket = assign(socket, :left_robotB, 750)
    socket = assign(socket, :robotB_start, "")
    socket = assign(socket, :robotB_goals, [])

    socket = assign(socket, :obstacle_pos, MapSet.new())
    socket = assign(socket, :timer_tick, 300)


    {:ok,socket}

  end

  @doc """
  Render the Grid with the coordinates and robot's location based
  on the "img_robotA" or "img_robotB" variable assigned in the mount/3 function.
  This function will be dynamically called when there is a change
  in the values of any of these variables =>
  "img_robotA", "bottom_robotA", "left_robotA", "robotA_start", "robotA_goals",
  "img_robotB", "bottom_robotB", "left_robotB", "robotB_start", "robotB_goals",
  "obstacle_pos", "timer_tick"
  """
  def render(assigns) do

    ~H"""
    <div id="dashboard-container">

      <div class="grid-container">
        <div id="alphabets">
          <div> A </div>
          <div> B </div>
          <div> C </div>
          <div> D </div>
          <div> E </div>
          <div> F </div>
        </div>

        <div class="board-container">
          <div class="game-board">
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
            <div class="box"></div>
          </div>

          <%= for obs <- @obstacle_pos do %>
            <img  class="obstacles"  src="/images/stone.png" width="50px" style={"bottom: #{elem(obs,1)}px; left: #{elem(obs,0)}px"}>
          <% end %>

          <div class="robot-container" style={"bottom: #{@bottom_robotA}px; left: #{@left_robotA}px"}>
            <img id="robotA" src={"/images/#{@img_robotA}"} style="height:70px;">
          </div>

          <div class="robot-container" style={"bottom: #{@bottom_robotB}px; left: #{@left_robotB}px"}>
            <img id="robotB" src={"/images/#{@img_robotB}"} style="height:70px;">
          </div>

        </div>

        <div id="numbers">
          <div> 1 </div>
          <div> 2 </div>
          <div> 3 </div>
          <div> 4 </div>
          <div> 5 </div>
          <div> 6 </div>
        </div>

      </div>
      <div id="right-container">

        <div class="timer-card">
          <label style="text-transform:uppercase;width:100%;font-weight:bold;text-align:center" >Timer</label>
            <p id="timer" ><%= @timer_tick %></p>
        </div>

        <div class="goal-card">
          <div style="text-transform:uppercase;width:100%;font-weight:bold;text-align:center" > Goal positions </div>
          <div style="display:flex;flex-flow:wrap;width:100%">
            <div style="width:50%">
              <label>Robot A</label>
              <%= for i <- @robotA_goals do %>
                <div><%= i %></div>
              <% end %>
            </div>
            <div  style="width:50%">
              <label>Robot B</label>
              <%= for i <- @robotB_goals do %>
              <div><%= i %></div>
              <% end %>
            </div>
          </div>
        </div>

        <div class="position-card">
          <div style="text-transform:uppercase;width:100%;font-weight:bold;text-align:center"> Start Positions </div>
          <form phx-submit="start_clock" style="width:100%;display:flex;flex-flow:row wrap;">
            <div style="width:100%;padding:10px">
              <label>Robot A</label>
              <input name="robotA_start" style="background-color:white;" value={"#{@robotA_start}"}>
            </div>
            <div style="width:100%; padding:10px">
              <label>Robot B</label>
              <input name="robotB_start" style="background-color:white;" value={"#{@robotB_start}"}>
            </div>

            <button  id="start-btn" type="submit">
              <svg xmlns="http://www.w3.org/2000/svg" style="height:30px;width:30px;margin:auto" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" />
              </svg>
            </button>

            <button phx-click="stop_clock" id="stop-btn" type="button">
              <svg xmlns="http://www.w3.org/2000/svg" style="height:30px;width:30px;margin:auto" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8 7a1 1 0 00-1 1v4a1 1 0 001 1h4a1 1 0 001-1V8a1 1 0 00-1-1H8z" clip-rule="evenodd" />
              </svg>
            </button>
          </form>
        </div>

      </div>

    </div>
    """
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
  #IO.inspect(all_pos)

  end

  def pos_converter(plant_positions) do
    all_pos = all_pos()
    goal_locs = Enum.map(plant_positions, fn num -> Enum.at(all_pos, num - 1 ) end)
    goal_locs
  end

  def fetch_locations do
    string=File.read!("Plant_Positions.csv")
    list=String.split(string, "\n")
    list = list -- [List.first(list)]
    list= Enum.map(list , fn string -> String.split(string, "," ) end)
    list = Enum.concat(list)
    plant_positions = Enum.map(list, fn string -> String.to_integer(string) end)
    #IO.inspect(plant_positions)
    goal_locs = pos_converter(plant_positions)
    weeding_targets = Enum.map(goal_locs, fn goal ->
      ind = Enum.find_index(goal_locs,fn x -> x == goal end)
      if rem(ind,2) != 0 do
        goal
      end
    end)
    weeding_targets = Enum.uniq(weeding_targets) -- [nil]
    {:ok,pid}= Task.start_link(fn -> target_identifier(weeding_targets) end)
    Process.register(pid, :target_identifier)
    goal_locs
  end

  def target_identifier(weeding) do
    receive do
      {:find_type,goal,pid} ->
        param=Enum.find(weeding, fn x -> x == goal end)
        if param != nil do
          send(pid,{:goal_type,"weeding"})
        else
          send(pid,{:goal_type,"sowing"})
        end
    end
    target_identifier(weeding)
  end

  def min_turns(robot,goal) do
    [x,y,face] = robot
    [goal_x,goal_y] = goal
    cond do
      x == goal_x and  goal_y > y and face == :north or x == goal_x and  goal_y < y and face == :south or
      y == goal_y and goal_x > x and face == :east or y == goal_y and goal_x < x and face == :west or goal_x == x and goal_y == y ->
        0
      face == :north and goal_y >= y and goal_x != x or face == :south and goal_x != x and goal_y <= y or
      face == :east and goal_x >= x and goal_y != y or face == :west and goal_y != y and goal_x <= x ->
        1.5
      true ->
        2.5
    end
  end

  def loc_sorter(robotA,robotB,socket) do
    loc_list = fetch_locations()
    [startA_x,startA_y,face_A] = robotA
    [startB_x,startB_y,face_B] = robotB
    n_goals=Enum.count(loc_list)
    split=round(n_goals/2)



    #loc_list=Enum.map(goal_locs, fn [goal_x,goal_y] -> [String.to_integer(goal_x),String.to_atom(goal_y)] end )
    loc_mapsA=Enum.map(loc_list,fn [goal_x,goal_y]-> %{coords: [goal_x,goal_y], min_moves: abs(goal_x-startA_x)+abs(@robot_map_y_atom_to_num[goal_y]-@robot_map_y_atom_to_num[startA_y]) + min_turns(robotA,[goal_x,goal_y]) } end )
    sorted_loc_mapsA=Enum.sort_by(loc_mapsA,&(&1.min_moves))
    IO.inspect(sorted_loc_mapsA)
    sorted_loc_listA=Enum.map(sorted_loc_mapsA,fn %{coords: [a,b], min_moves: _c} -> [a,b] end )
    movesA=Enum.map(sorted_loc_mapsA,fn %{coords: [_a,_b], min_moves: c} -> c end)
    total_movesA=Enum.sum(movesA)

    loc_mapsB=Enum.map(loc_list,fn [goal_x,goal_y]-> %{coords: [goal_x,goal_y], min_moves: abs(goal_x-startB_x)+abs(@robot_map_y_atom_to_num[goal_y]-@robot_map_y_atom_to_num[startB_y])+ min_turns(robotB,[goal_x,goal_y]) } end )
    sorted_loc_mapsB=Enum.sort_by(loc_mapsB,&(&1.min_moves))
    IO.inspect(sorted_loc_mapsB)
    sorted_loc_listB=Enum.map(sorted_loc_mapsB,fn %{coords: [a,b], min_moves: _c} -> [a,b] end )
    movesB=Enum.map(sorted_loc_mapsB,fn %{coords: [_a,_b], min_moves: c} -> c end)
    total_movesB=Enum.sum(movesB)


    [robotA_targets,robotB_targets]=if total_movesA <= total_movesB do
      {robotA_targets,robotB_targets}=Enum.split(sorted_loc_listA,split)
      robotB_targets=sorted_loc_listB -- robotA_targets
      [robotA_targets ++ [List.last(robotB_targets)],robotB_targets -- [List.last(robotB_targets)]]
    else
      {robotB_targets,robotA_targets}=Enum.split(sorted_loc_listB,split)
      robotA_targets=sorted_loc_listA -- robotB_targets
      [robotA_targets,robotB_targets] = [robotA_targets -- [List.last(robotA_targets)],robotB_targets ++ [List.last(robotA_targets)]]
    end
    [robotA_targets,robotB_targets] = [robotA_targets ++ [List.last(robotB_targets)],robotB_targets -- [List.last(robotB_targets)]]

    display_goals(robotA_targets,robotB_targets,socket)

    sorted_loc_list=cond do
      robotA_targets ==[] and robotB_targets !=[] ->
        robotA_targets=[[startA_x,startA_y]]
        [robotA_targets,robotB_targets]
      robotA_targets != [] and robotB_targets ==[] ->
        robotB_targets=[[startB_x,startB_y]]
        [robotA_targets,robotB_targets]
      robotA_targets == [] and robotB_targets ==[] ->
          robotB_targets=[[startB_x,startB_y]]
          robotA_targets=[[startA_x,startA_y]]
          [robotA_targets,robotB_targets]
      true ->
        [robotA_targets,robotB_targets]
    end
    [robotA_targets,robotB_targets]=sorted_loc_list
    current_targets=[List.first(robotA_targets),List.first(robotB_targets)]
    robotA_targets=robotA_targets--[List.first(robotA_targets)]
    robotB_targets=robotB_targets--[List.first(robotB_targets)]

    robotA_targets = robotA_targets
    robotB_targets = robotB_targets
    [robotA_targets,robotB_targets,current_targets]
  end

  def display_goals(robotA_targets,robotB_targets,socket) do
    str_listA = Enum.map(robotA_targets, fn [x,y] ->
      y = Atom.to_string(y)
      str = "#{x},#{y}"
    end)
    str_listB = Enum.map(robotB_targets, fn [x,y] ->
      y = Atom.to_string(y)
      str = "#{x},#{y}"
    end)
    IO.inspect(str_listA)
    IO.inspect(str_listB)
    data = %{GoalsA: str_listA, GoalsB: str_listB}
    Phoenix.PubSub.local_broadcast(Task4CPhoenixServer.PubSub,"robot:goals",data)
    IO.puts("yep")
  end

  def handle_info(%{event: "update_timer_tick", payload: timer_data, topic: "timer:update"}, socket) do
    socket = assign(socket, :timer_tick, timer_data.time)
    {:noreply, socket}
  end




  def starter(robotA,robotB,socket) do

    [robotA_targets,robotB_targets,current_targets] = loc_sorter(robotA,robotB,socket)
    [current_target_A, current_target_B] = current_targets
    [x,y,facing]= robotA
    paramsA = {{x,y,facing},"stopped",{x,y,facing}}
    #{{a_x,a_y,a_facing},a_action,{a1_x,a1_y,a1_facing}}

    [x,y,facing]= robotB
    paramsB = {{x,y,facing},"stopped",{x,y,facing}}

    {:ok,out_file}= File.open("obstacles.txt",[:write])
    {:ok,pid}=Task.start_link(fn -> interceptor(paramsA,paramsB,out_file) end)
    Process.register(pid,:interceptor)
    {:ok,pid}=Task.start_link(fn -> goal_manager_A(robotA_targets,current_target_A) end)
    Process.register(pid,:goal_manager_A)
    {:ok,pid}=Task.start_link(fn -> goal_manager_B(robotB_targets,current_target_B) end)
    Process.register(pid,:goal_manager_B)
    {:ok,pid}=Task.start_link(fn -> goal_exchanger() end)
    Process.register(pid,:goal_exchanger)

  end

  def interceptor(last_report_A,last_report_B,out_file) do
    #IO.inspect(last_report_A)
    #IO.inspect(last_report_B)


    {{{a_x,a_y,a_facing},a_action,{a1_x,a1_y,a1_facing}},apid}=receive do
      {:A_is_gonna_be_at,{a_x,a_y,a_facing},:A_action,a_action,:A_is_at,{a1_x,a1_y,a1_facing},:A_pid,apid} ->
        {{{a_x,a_y,a_facing},a_action,{a1_x,a1_y,a1_facing}},apid}
      after 200 ->
        {last_report_A,nil}
    end

    {{{b_x,b_y,b_facing},b_action,{b1_x,b1_y,b1_facing}},bpid}=receive do
      {:B_is_gonna_be_at,{b_x,b_y,b_facing},:B_action,b_action,:B_is_at,{b1_x,b1_y,b1_facing},:B_pid,bpid} ->
        #IO.puts(b_action)
        {{{b_x,b_y,b_facing},b_action,{b1_x,b1_y,b1_facing}},bpid}
      after 200->
        {last_report_B,nil}
    end
    params_A = {{a_x,a_y,a_facing},a_action,{a1_x,a1_y,a1_facing}}
    params_B = {{b_x,b_y,b_facing},b_action,{b1_x,b1_y,b1_facing}}
    {flag_A,flag_B} = cond do
      apid == nil and bpid != nil  ->
        flag_A = true
        flag_B = false
        {flag_A,flag_B}
      bpid == nil and apid != nil ->
        flag_A = false
        flag_B = true
        {flag_A,flag_B}
      bpid == nil and apid == nil ->
        flag_A = true
        flag_B = true
        {flag_A,flag_B}
      true ->
        flag_A = false
        flag_B = false
        {flag_A,flag_B}
    end


    #actions => turning farming stopped halting moving
    #signals to be given => escape , halt , proceed , exchange



      cond do
      a_action == "farming" and b_action == "moving" and [a_x,a_y]==[b_x,b_y] or
      a_action == "stopped" and b_action == "moving" and [a_x,a_y] == [b_x,b_y] ->
        cond do
          flag_A and !flag_B ->
            send(bpid,{:signal,"escape"})
          flag_B and !flag_A ->
            send(apid,{:signal,"proceed"})
          flag_B and flag_A ->
            :ok
          true ->

            send(apid,{:signal,"proceed"})
            send(bpid,{:signal,"escape"})
            {"A proceed, B escape"}
        end

      b_action == "farming" and a_action == "moving" and [a_x,a_y]==[b_x,b_y] or
      b_action == "stopped" and a_action == "moving" and [a_x,a_y] == [b_x,b_y] ->
        cond do
          flag_A and !flag_B ->
            send(bpid,{:signal,"proceed"})
          flag_B and !flag_A ->
            send(apid,{:signal,"escape"})
          flag_A and flag_B ->
            :ok
          true ->

            send(bpid,{:signal,"proceed"})
            send(apid,{:signal,"escape"})
            {"A escape, B proceed"}
        end

      a_action=="moving" and b_action=="turning" and [a_x,a_y]==[b_x,b_y] or
      a_action=="moving" and b_action=="moving" and [a_x,a_y]==[b_x,b_y] ->

        cond do
          flag_B and !flag_A->
            if b_action == "turning" do
              send(apid,{:signal,"halt"})
            else
              send(apid,{:signal,"escape"})
            end

          flag_A and !flag_B->
            if b_action == "turning" do
              send(bpid,{:signal,"proceed"})
            else
              send(bpid,{:signal,"escape"})
            end
          flag_A and flag_B ->
            :ok
          true ->

            send(apid,{:signal,"halt"})
            send(bpid,{:signal,"proceed"})
            {"A halt, B proceed"}
        end

      a_action=="turning" and b_action=="moving" and [a_x,a_y]==[b_x,b_y] ->

        cond do
          flag_B and !flag_A ->
            send(apid,{:signal,"proceed"})
          flag_A and !flag_B ->
            send(bpid,{:signal,"halt"})
          flag_A and flag_B ->
            :ok
          true ->

            send(apid,{:signal,"proceed"})
            send(bpid,{:signal,"halt"})
            {"A proceed, B halt"}
        end

      a_action=="moving" and b_action=="moving" and [a_x,a_y]==[b1_x,b1_y] and [a1_x,a1_y]==[b_x,b_y]  ->

        cond do
          flag_A and !flag_B ->
            send(bpid,{:signal,"escape"})
          flag_B and !flag_A ->
            send(apid,{:signal,"escape"})
          flag_A and flag_B ->
            :ok
          true ->
            send(:goal_exchanger,{:interceptor,{[a_x,a_y],[b_x,b_y]}})
            receive do
              :ok -> :ok
            end

            send(apid,{:signal,"goal_exchange"})
            send(bpid,{:signal,"goal_exchange"})
            {"goal_exchanged"}
        end

      a_action == "halting" or b_action == "halting" ->


        Process.sleep(100)
        cond do
          flag_A and !flag_B ->
            send(:goal_manager_B,{:update_current_target,[6,:d]})
            send(bpid,{:signal,"terminate"})
          flag_B and !flag_A ->
            send(:goal_manager_A,{:update_current_target,[6,:b]})
            send(apid,{:signal,"terminate"})
          flag_A and flag_B ->
            :ok
          true ->
            send(:goal_manager_B,{:update_current_target,[6,:e]})
            send(:goal_manager_A,{:update_current_target,[6,:b]})
            send(apid,{:signal,"terminate"})
            send(bpid,{:signal,"terminate"})
            {"terminated"}
        end

      true ->
        cond do
          flag_A and !flag_B ->
            send(bpid,{:signal,"proceed"})
          flag_B and !flag_A->
            send(apid,{:signal,"proceed"})
          flag_A and flag_B ->
            :ok
          true ->
            send(apid,{:signal,"proceed"})
            send(bpid,{:signal,"proceed"})
            {"both proceed"}
        end
     end

    IO.binwrite(out_file," robot A #{a_x} #{a_y} #{a_facing} #{a_action} and robot B #{b_x} #{b_y} #{b_facing} #{b_action}  \n\n " )
    interceptor(params_A,params_B,out_file)
  end

  def goal_exchanger() do
    receive do
      {:interceptor,{[a_x,a_y],[b_x,b_y]}} ->
        {[a_x,a_y],[b_x,b_y]}
        send(:goal_manager_A,{:goal_exchanger,:goal_request})
        receive do
          {:goal_A,current_target_A} ->
            send(:goal_manager_B,{:goal_exchanger,:goal_request})
            receive do
              {:goal_B,current_target_B} ->
                cond do
                  current_target_A == [nil,nil] ->
                    send(:goal_manager_A,{:new_goal,current_target_B})
                    send(:goal_manager_B,{:new_goal,[a_x,a_y]})
                    send(:interceptor,:ok)
                  current_target_B == [nil,nil]  ->
                    send(:goal_manager_A,{:new_goal,[b_x,b_y]})
                    send(:goal_manager_B,{:new_goal,current_target_A})
                    send(:interceptor,:ok)
                  true ->
                    send(:goal_manager_A,{:new_goal,current_target_B})
                    send(:goal_manager_B,{:new_goal,current_target_A})
                    send(:interceptor,:ok)
                end
            end
        end
    end
    goal_exchanger()
  end

  def goal_manager_A(robotA_targets,current_target_A) do

    receive do
      {:Robo_A, id} ->
        send(id,{:goal,current_target_A})
        goal_manager_A(robotA_targets,current_target_A)

      {:Destination_confirmation_A,_id} ->
        if Enum.count(robotA_targets) != 0 do

          new_target=sorter(robotA_targets,current_target_A)
          robotA_targets=robotA_targets--[new_target]
          data = %{Client: "A" ,update_type: "sub", goal: current_target_A}
          Phoenix.PubSub.local_broadcast(Task4CPhoenixServer.PubSub,"robot:goals",data)
          goal_manager_A(robotA_targets,new_target)
        else
          new_target=[nil , nil]
          goal_manager_A(robotA_targets,new_target)
        end

      {:goal_exchanger,_} ->
        send(:goal_exchanger,{:goal_A,current_target_A})
        receive do
          {:new_goal,new_target} ->
            data = %{Client: "A" ,update_type: "xchg", goal: nil}
            Phoenix.PubSub.local_broadcast(Task4CPhoenixServer.PubSub,"robot:goals",data)
            goal_manager_A(robotA_targets,new_target)
        end

      {:update_current_target,[x,y]} ->
        data = %{Client: "A" ,update_type: "add", goal: [x,y]}
        Phoenix.PubSub.local_broadcast(Task4CPhoenixServer.PubSub,"robot:goals",data)
        goal_manager_A(robotA_targets,[x,y])
    end
  end

  def goal_manager_B(robotB_targets,current_target_B) do

    receive do
      {:Robo_B, id} ->
        send(id,{:goal,current_target_B})
        goal_manager_B(robotB_targets,current_target_B)

      {:Destination_confirmation_B,_id} ->
        if Enum.count(robotB_targets) != 0 do
          new_target=sorter(robotB_targets,current_target_B)
          robotB_targets=robotB_targets--[new_target]
          data = %{Client: "B" ,update_type: "sub", goal: current_target_B}
        Phoenix.PubSub.local_broadcast(Task4CPhoenixServer.PubSub,"robot:goals",data)
          goal_manager_B(robotB_targets,new_target)
        else
          new_target=[nil , nil]
          goal_manager_B(robotB_targets,new_target)
        end

      {:goal_exchanger,_} ->
        send(:goal_exchanger,{:goal_B,current_target_B})
        receive do
          {:new_goal,new_target} ->

            data = %{Client: "B" ,update_type: "xchg", goal: nil}
            Phoenix.PubSub.local_broadcast(Task4CPhoenixServer.PubSub,"robot:goals",data)
            goal_manager_B(robotB_targets,new_target)
        end

      {:update_current_target,[x,y]} ->
        data = %{Client: "B" ,update_type: "add", goal: [x,y]}
        Phoenix.PubSub.local_broadcast(Task4CPhoenixServer.PubSub,"robot:goals",data)
        goal_manager_B(robotB_targets,[x,y])
    end
  end

  def sorter(total,current) do
    [x,y] = current
    y = @robot_map_y_atom_to_num[y]
    loc_maps=Enum.map(total,fn [goal_x,goal_y]-> %{coords: [goal_x,goal_y], min_moves: abs(goal_x-x)+abs(@robot_map_y_atom_to_num[goal_y]-y) } end )
    sorted_loc_maps=Enum.sort_by(loc_maps,&(&1.min_moves))
    IO.inspect(sorted_loc_maps)
    sorted_loc_list=Enum.map(sorted_loc_maps,fn %{coords: [a,b], min_moves: _c} -> [a,b] end )
    new_target = List.first(sorted_loc_list)

  end




  @doc """
  Handle the event "start_clock" triggered by clicking
  the PLAY button on the dashboard.
  """
  def handle_event("start_clock", data, socket) do

    IO.inspect(data)
    socket = assign(socket, :robotA_start, data["robotA_start"])
    socket = assign(socket, :robotB_start, data["robotB_start"])

    #starter()
    stringA= data["robotA_start"]
    stringB = data["robotB_start"]
    [startA,startB]=convert_strings(stringA,stringB)
    {:ok,pid} = Task.start_link(fn -> start_loc_holder_A(startA) end )
    Process.register(pid,:start_loc_holder_A)
    {:ok,pid} = Task.start_link(fn -> start_loc_holder_B(startB) end )
    Process.register(pid,:start_loc_holder_B)
    [startA_x,startA_y,face_A] = startA
    [startB_x,startB_y,face_B] = startB
    starter(startA,startB,socket)
    Task4CPhoenixServerWeb.Endpoint.broadcast("timer:start", "start_timer", %{})
    {:noreply, socket}
  end

  def convert_strings(stringA,stringB) do
    [x_coord_A,y_coord_A,face_A] = String.split(stringA,",")
    [x_coord_B,y_coord_B,face_B] = String.split(stringB,",")
    startB = [String.to_integer(String.trim(x_coord_B)), String.to_atom(String.trim(y_coord_B)),String.to_atom(String.trim(face_B))]
    startA =[String.to_integer(String.trim(x_coord_A)), String.to_atom(String.trim(y_coord_A)),String.to_atom(String.trim(face_A))]
    [startA,startB]
  end

  def start_loc_holder_A(start_A) do
    receive do
      {:give_start_pos_Robot_A, :PID,pid} ->
        send(pid,{:start_pos_A,start_A})
    end
    start_loc_holder_A(start_A)
  end

  def start_loc_holder_B(start_B) do
    receive do
      {:give_start_pos_Robot_B, :PID,pid} ->
        send(pid,{:start_pos_B,start_B})
    end
    start_loc_holder_B(start_B)
  end

  @doc """
  Handle the event "stop_clock" triggered by clicking
  the STOP button on the dashboard.
  """
  def handle_event("stop_clock", _data, socket) do
    Task4CPhoenixServerWeb.Endpoint.broadcast("timer:stop", "stop_timer", %{})
    ipid = Process.whereis(:interceptor)
    #Process.kill(ipid, :kill)

    #################################
    ## edit the function if needed ##
    #################################
    {:noreply, socket}
  end

  def handle_info(%{event: "update_timer_tick", payload: timer_data, topic: "timer:update"}, socket) do
    socket = assign(socket, :timer_tick, timer_data.time)
    {:noreply, socket}
  end

  @doc """
  Callback function to handle incoming data from the Timer module
  broadcasted on the "timer:update" topic.
  Assign the value to variable "timer_tick" for each countdown.
  """
  #def handle_info(%{event: "update_timer_tick", payload: timer_data, topic: "timer:update"}, socket) do
    #Logger.info("Timer tick: #{timer_data.time}")
    #Process.sleep(1000)
    #socket = assign(socket, :timer_tick, timer_data.time)
    #{:noreply, socket}
  #end



  @doc """
  Callback function to handle any incoming data from the RobotChannel module
  broadcasted on the "robot:update" topic.
  Assign the values to the variables => "img_robotA", "bottom_robotA", "left_robotA",
  "img_robotB", "bottom_robotB", "left_robotB" and "obstacle_pos" as received.
  Make sure to add a tuple of format: { < obstacle_x >, < obstacle_y > } to the MapSet object "obstacle_pos".
  These values must be in pixels. You may handle these variables in separate callback functions as well.
  """

  def handle_info(%{:obs_status => true , :x_pixel => obs_x, :y_pixel => obs_y},socket) do
    socket = assign(socket, :obstacle_pos,MapSet.new([{obs_x,obs_y}]))
    {:noreply, socket}
  end


  def handle_info(%{"client" => client, "left" => left ,"bottom" => bottom ,"face" => face_img}, socket) do



    IO.inspect("client #{client} left #{left} and bottom #{bottom} and face img #{face_img} ")
    socket = if client == "A" do

      socket = assign(socket, :img_robotA, face_img)
      socket = assign(socket, :bottom_robotA, bottom)
      socket = assign(socket, :left_robotA, left)
      socket
    else
      #IO.puts('hola')
      socket = assign(socket, :img_robotB, face_img)
      socket = assign(socket, :bottom_robotB, bottom)
      socket = assign(socket, :left_robotB, left)
      socket
    end
    {:noreply, socket}
  end

  def handle_info(%{GoalsA: str_listA, GoalsB: str_listB}, socket) do

    socket = assign(socket, :robotA_goals, str_listA )
    socket = assign(socket, :robotB_goals, str_listB )
    {:noreply, socket}
  end
  def handle_info(%{Client: client,update_type: operation, goal: goal},socket) do

    [x,y] = goal
    socket = cond do
      client == "A" and operation == "sub" ->

        data = socket.assigns[:robotA_goals]
        socket = assign(socket,:robotA_goals, data -- ["#{x},#{Atom.to_string(y)}"])

      client == "A" and operation == "add" ->
        data = socket.assigns[:robotA_goals]
        socket = assign(socket,:robotA_goals, data ++ ["#{x},#{Atom.to_string(y)}"])

      client == "B" and operation == "sub" ->
        data = socket.assigns[:robotB_goals]
        socket = assign(socket,:robotB_goals, data -- ["#{x},#{Atom.to_string(y)}"])

      client == "B" and operation ==  "add" ->
        data = socket.assigns[:robotB_goals]
        socket = assign(socket,:robotB_goals, data ++ ["#{x},#{Atom.to_string(y)}"])
      true ->
        data_a = socket.assigns[:robotA_goals]
        data_b = socket.assigns[:robotB_goals]
        m = List.first(data_a)
        n = List.first(data_b)
        data = List.delete(data_a,List.first(data_a))
        data= data ++ [n]
        socket = assign(socket,:robotA_goals, data )
        data = List.delete(data_b,List.first(data_b))
        data= data ++ [m]
        socket = assign(socket,:robotB_goals, data )
    end
    {:noreply,socket}
  end
end
