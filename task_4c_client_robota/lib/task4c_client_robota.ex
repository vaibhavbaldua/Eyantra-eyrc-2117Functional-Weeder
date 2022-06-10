defmodule Task4CClientRobotA do
  # max x-coordinate of table top
  @table_top_x 6
  # max y-coordinate of table top
  @table_top_y :f
  # mapping of y-coordinates
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5, :f => 6}

  @robot_map_face_atom_to_axis %{:east => 'x' , :west => 'x' , :south => 'y' , :north => 'y' }

  @doc """
  Places the robot to the default position of (1, A, North)

  Examples:

      iex> Task4CClientRobotA.place
      {:ok, %Task4CClientRobotA.Position{facing: :north, x: 1, y: :a}}
  """
  def place do
    {:ok, %Task4CClientRobotA.Position{}}
  end

  def place(x, y, _facing) when x < 1 or y < :a or x > @table_top_x or y > @table_top_y do
    {:failure, "Invalid position"}
  end

  def place(_x, _y, facing) when facing not in [:north, :east, :south, :west] do
    {:failure, "Invalid facing direction"}
  end

  @doc """
  Places the robot to the provided position of (x, y, facing),
  but prevents it to be placed outside of the table and facing invalid direction.

  Examples:

      iex> Task4CClientRobotA.place(1, :b, :south)
      {:ok, %Task4CClientRobotA.Position{facing: :south, x: 1, y: :b}}

      iex> Task4CClientRobotA.place(-1, :f, :north)
      {:failure, "Invalid position"}

      iex> Task4CClientRobotA.place(3, :c, :north_east)
      {:failure, "Invalid facing direction"}
  """
  def place(x, y, facing) do
    {:ok, %Task4CClientRobotA.Position{x: x, y: y, facing: facing}}
  end

  @doc """
  Provide START position to the robot as given location of (x, y, facing) and place it.
  """
  def start(x, y, facing) do
    place(x, y, facing)
  end

  @doc """
  Main function to initiate the sequence of tasks to achieve by the Client Robot A,
  such as connect to the Phoenix server, get the robot A's start and goal locations to be traversed.
  Call the respective functions from this module and others as needed.
  You may create extra helper functions as needed.
  """

  def get_goal do
    goal=Task4CClientRobotA.PhoenixSocketClient.get_goal
    goal
  end

  def killer do
    pid = Process.whereis(:register)
    if pid == nil do
      :ok
    else
      Process.exit(pid,:kill)
    end
    pid = Process.whereis(:channel_reg)
    if pid == nil do
      :ok
    else
      Process.exit(pid,:kill)
    end

    pid = Process.whereis(:weed_reg)
    if pid == nil do
      :ok
    else
      Process.exit(pid,:kill)
    end
  end

  def confirm_goal(type,goal) do
    Task4CClientRobotA.PhoenixSocketClient.confirm_goal(type,goal)
  end

  def get_start do
    Task4CClientRobotA.PhoenixSocketClient.get_start
  end

  def farming(robot,type) do
    comm(robot,"farming")
    [x,y,face] = [robot.x,robot.y,robot.facing]
    {robot,side} = cond do
      face == :east ->
        {robot,:left}

      face == :west ->
        foo = spawner(robot)
        if foo do
          robot = right(robot)
          spawner(robot)
          robot = move(robot)
          spawner(robot)
          {robot,:left}
        end
        robot = move(robot)
        spawner(robot)
        {robot,:right}

      face == :north ->
        foo = spawner(robot)
        if foo do
          robot = left(robot)
          spawner(robot)
          robot = move(robot)
          spawner(robot)
          {robot,:right}
        end
        robot = move(robot)
        spawner(robot)
        {robot,:left}

      true ->
        {robot,:right}
    end

    if type == "weeding" do
      Alphabot.fetch(robot,side)
    else
      Alphabot.seed_sowing(robot,side)
    end
    robot
  end

  def obs_detect(robot) do
    params = [robot.x,robot.y,robot.facing]
    obs_list =[[2, :a, :east ],[3, :a, :west],[1, :b, :north ], [1, :c, :south],[2, :d, :east ],[3, :d, :west]]
    Enum.member?(obs_list,params)
  end


  def main do
    Task4CClientRobotA.PhoenixSocketClient.connect_server
    [x,y,facing]=get_start
    {:ok,robot}=start(x,y,facing)
    stop(robot)
  end

  def deposit_stalks(robot) do

    if robot.x == 3 do
      {robot,side} = cond do
        robot.facing == :east  ->
          {robot,:left}

        robot.facing == :west ->
          {robot,:right}

        robot.facing == :north ->
          robot = right(robot)
          {robot,:left}

        true ->
          robot = right(robot)
          {robot,:right}
      end
      Alphabot.slide_box(robot,side)
    else
      {robot,side} = cond do
        robot.facing == :south  ->
          {robot,:left}

        robot.facing == :north ->
          {robot,:right}

        robot.facing == :east ->
          robot = right(robot)
          {robot,:left}

        true ->
          robot = right(robot)
          {robot,:right}
      end
      Alphabot.slide_box(robot,side)
    end
  end



  @doc """
  Provide GOAL positions to the robot as given location of [(x1, y1),(x2, y2),..] and plan the path from START to these locations.
  Make a call to ToyRobot.PhoenixSocketClient.send_robot_status/2 to get the indication of obstacle presence ahead of the robot.
  """
  def stop(robot) do
    parent=self()
    pid = spawn(fn -> Alphabot.starter end)
    Process.register(pid,:starter)
    rpid=spawn_link(fn -> register([]) end)
    Process.register(rpid,:register) #gone
    pid=spawn_link(fn -> Alphabot.robot_status(:unturned) end )
    Process.register(pid,:robot_status)
    {:ok,robot}=destination_finder(robot)
    {:ok,robot} = watcher(robot)
    {:ok,robot}
  end

  def watcher(robot) do
    {robot,next_move}=comm(robot,"halting")
    cond do
      next_move == "goal_exchange" or next_move == "escaped" ->
        {:ok,robot} = destination_finder(robot)
        watcher(robot)
      next_move == "proceed" ->
        spawner(robot)
        watcher(robot)
      next_move == "terminate" ->
        {:ok,robot} = destination_finder(robot)
        robot = deposit_stalks(robot)
        killer
        {:ok,robot}
    end
  end



  def destination_finder(initial_position) do
    parent=self()
    final_position=helper(initial_position)
    [goal_x,goal_y,goal_type] = get_goal
    if [goal_x,goal_y] != [nil, nil] do
      cond do
        final_position.y != goal_y or goal_x != final_position.x ->
          final_position
          destination_finder(final_position)

        final_position.y==goal_y and final_position.x==goal_x and [goal_x,goal_y] != [1,:a] or
        final_position.y==goal_y and final_position.x==goal_x and [goal_x,goal_y] != [6,:f]  ->
          farming(final_position,goal_type)
          confirm_goal(goal_type,[goal_x,goal_y])
          final_position
          destination_finder(final_position)

         true ->
          final_position
      end

    else
      spawner(final_position)
      {:ok,final_position}
    end
  end

  def helper(robot) do
    parent=self()
    [goal_x,goal_y,goal_type] = get_goal
    cond do
      robot.facing==:east and goal_x > robot.x or robot.facing==:west and goal_x < robot.x or robot.facing==:north and goal_y <= robot.y or robot.facing==:south and goal_y >= robot.y ->
        robot=translate_x(robot)
        robot=translate_y(robot)
        robot
      robot.facing==:east and goal_x <= robot.x or robot.facing==:west and goal_x >= robot.x or robot.facing==:north and goal_y > robot.y or robot.facing==:south and goal_y < robot.y ->
        robot=translate_y(robot)
        robot=translate_x(robot)
        robot
    end
  end



  def spawner(robot) do
    parent=self()
    Task4CClientRobotA.PhoenixSocketClient.report_robot_status(robot)
    obs_bool = obs_detect(robot)
    if obs_bool == true do
      Task4CClientRobotA.PhoenixSocketClient.obs_detected(robot)
    end
    obs_bool
  end




  def comm(robot,action) do
    next_move=Task4CClientRobotA.PhoenixSocketClient.report_next_move(robot,action)
    cond do
      next_move == "halt" ->
        Process.sleep(1500)
        spawner(robot)
        comm(robot,"moving")
      next_move == "escape" ->
        axis = @robot_map_face_atom_to_axis[robot.facing]
        robot = move_adjacent(robot,axis)
        spawner(robot)
        {robot,"escaped"}
      true ->
        {robot,next_move}
    end
  end





  def translate_y(robot) do
    pid=self()
    [goal_x,goal_y,goal_type] = get_goal
    #IO.inspect([goal_x,goal_y])
    cond do
      robot.y == goal_y or goal_y==nil ->
        robot
      robot.facing == :north and goal_y > robot.y or robot.facing == :south and goal_y < robot.y ->
        flag = spawner(robot)
        if flag == true do
          moved_adjacent = move_adjacent(robot, 'y')
          if moved_adjacent==robot do
            moved_adjacent
          else
            translate_y(moved_adjacent)
          end
        else
          {robot,msg}=comm(robot,"moving")
          cond do
            msg == "goal_exchange" or msg == "escaped" ->
              translate_y(robot)
            msg == "proceed" ->
              x=move(robot)
              translate_y(x)
          end

        end
      robot.facing == :north and goal_y < robot.y or robot.facing == :south and goal_y > robot.y ->
        spawner(robot)
        {robot,msg} = comm(robot,"turning")
        left_robot=left(robot)
        translate_y(left_robot)
      true ->
        spawner(robot)
        {robot,msg} = comm(robot,"turning")
        rotated_robot=rotate_robot_y(robot,goal_y)
        translate_y(rotated_robot)
    end
  end

  def translate_x(robot) do
    pid=self()
    [goal_x,goal_y,goal_type] = get_goal
    #IO.inspect([goal_x,goal_y])
    cond do
      robot.x == goal_x or goal_x==nil -> robot
      robot.facing == :east and goal_x > robot.x or robot.facing == :west and goal_x < robot.x ->
        flag = spawner(robot)
        if flag == true do
          moved_adjacent = move_adjacent(robot, 'x')
          if moved_adjacent==robot do
            moved_adjacent
          else
            translate_x(moved_adjacent)
          end
        else
          {robot,msg} =comm(robot,"moving")
          if msg != "goal_exchange" or msg != "escaped" do
            x=move(robot)
            translate_x(x)
          else
            translate_x(robot)
          end
        end
      robot.facing == :east and goal_x < robot.x or robot.facing == :west and goal_x > robot.x ->
        spawner(robot)
        {robot,msg}=comm(robot,"turning")
        left_robot=left(robot)
        translate_x(left_robot)
      true ->
        spawner(robot)
        {robot,msg} = comm(robot,"turning")
        #IO.puts(3)
        rotated_robot=rotate_robot_x(robot,goal_x)
        #IO.puts(4)
        translate_x(rotated_robot)
    end
  end

  def register(list) do
    list=receive do
      {:check,{robot,turn}} ->
        {robot,turn}
        bool=Enum.member?(list,{robot,turn})
        list=if bool==true do
          send(:checker,{:result,false})
          list=list--[{robot,turn}]
          list
        else
          list=list++[{robot,turn}]
          send(:checker,{:result,true})
          list
        end
        list
      :reset ->
        list=[]
        list
    end
    register(list)
  end

  def reg_check(robot,turn) do

    send(:register,{:check,{robot,turn}})
    bool=receive do
      {:result,bool} -> bool
    end
    bool
  end
  def spawn_checker(robot,turn) do
    parent=self()
    pid=spawn_link(fn -> result=reg_check(robot,turn)
      send(parent,{:result,result}) end)
    Process.register(pid,:checker)
    #IO.puts(2)
    result=receive do
      {:result,result}-> result
    end
    result
  end

  #@spec move_adjacent(%CLI.Position{:facing => any, optional(any) => any}, any, any) :: any
  def move_adjacent(robot, axis) do
    comm(robot,"turning")
    left_robot=left(robot)
    left_bool=spawner(left_robot)
    cond do

      axis=='y' and robot.facing== :north and robot.x == 6 and left_bool==false or axis=='y' and robot.facing==:south and robot.x==1 and left_bool==false or
      axis=='x' and robot.facing== :east and @robot_map_y_atom_to_num[robot.y] == 1 and left_bool==false or axis=='x' and robot.facing== :west and
      @robot_map_y_atom_to_num[robot.y] == 6 and left_bool==false ->

        {left_robot,msg}=comm(left_robot,"moving")

        if msg != "goal_exchange" or msg != "escaped" do
          move(left_robot)
        else
          left_robot
        end
      axis=='y' and robot.facing== :north and robot.x == 6 and left_bool==true or axis=='y' and robot.facing==:south and robot.x==1 and left_bool==true or
      axis=='x' and robot.facing== :east and @robot_map_y_atom_to_num[robot.y] == 1 and left_bool==true or axis=='x' and robot.facing== :west and
      @robot_map_y_atom_to_num[robot.y] == 6 and left_bool==true ->
        comm(left_robot,"turning")
        opposite=left(left_robot)
        doom=spawner(opposite)
        if doom==true or axis=='y' and robot.x==6 and robot.y==:a or axis=='y' and robot.x==1 and robot.y==:f or axis=='x' and robot.y==:a and robot.x==1 or axis=='x' and robot.y==:f and robot.x==6 do
          comm(opposite,"turning")
          robot=right(opposite)
          spawner(robot)
          comm(robot,"turning")
          robot=right(robot)
          robot
        else
          {opposite,msg}=comm(opposite,"moving")
          if msg != "goal_exchange" or msg != "escaped" do
            returned=move(opposite)
            spawner(returned)
            comm(returned,"turning")
            robot=right(returned)
            flag=spawner(robot)
            if flag==true do
              axis=@robot_map_facing_to_axis[robot.facing]
              move_adjacent(robot,axis)
            else
              {robot,msg}=comm(robot,"moving")
              if msg != "goal_exchange" or msg != "escaped" do
                move(robot)
              else
                robot
              end
            end
          else
            opposite
          end
        end
      axis=='y' and robot.x < 6 and robot.x > 1 and left_bool==false or axis=='x' and
      @robot_map_y_atom_to_num[robot.y] > 1 and @robot_map_y_atom_to_num[robot.y] < 6 and left_bool==false ->
        {left_robot,msg}=comm(left_robot,"moving")
          if msg != "goal_exchange" or msg != "escaped" do
            move(left_robot)
          else
            left_robot
          end


      true ->

        comm(left_robot,"turning")
        robot=right(left_robot)
        spawner(robot)
        comm(robot,"turning")
        right_robot=right(robot)
        right_bool=spawner(right_robot)
        cond do
          axis=='y' and robot.facing==:north and robot.x == 1 and right_bool==false or axis=='y' and robot.facing== :south and robot.x == 6 and right_bool==false or
          axis=='x' and robot.facing==:east and @robot_map_y_atom_to_num[robot.y] == 6 and right_bool==false or axis=='x' and robot.facing== :west and
          @robot_map_y_atom_to_num[robot.y] == 1 and right_bool==false  ->

            {right_robot,msg}=comm(right_robot,"moving")
            if msg != "goal_exchange" or msg != "escaped" do
              move(right_robot)
            else
              right_robot
            end

          axis=='y' and robot.x < 6 and robot.x > 1 and right_bool==false and left_bool==true or axis=='x' and
          @robot_map_y_atom_to_num[robot.y] > 1 and @robot_map_y_atom_to_num[robot.y] < 6 and right_bool==false and left_bool==true ->
            {right_robot,msg}=comm(right_robot,"moving")
            if msg != "goal_exchange" or msg != "escaped" do
              move(right_robot)
            else
              right_robot
            end

          axis=='y' and robot.x < 6 and robot.x > 1 and right_bool==true and left_bool==true or axis=='x' and
          @robot_map_y_atom_to_num[robot.y] > 1 and @robot_map_y_atom_to_num[robot.y] < 6 and right_bool==true and left_bool==true ->
            comm(right_robot,"turning")
            opposite=right(right_robot)
            doom=spawner(opposite)
            if doom==true or axis=='y' and robot.x< 6 and robot.x> 1 and robot.y==:a or axis=='y' and robot.x< 6 and robot.x> 1 and robot.y==:f or axis=='x' and robot.y > :a and robot.y < :f and robot.x==1 or axis=='x' and robot.y > :a and robot.y < :f and robot.x==6 do
              comm(opposite,"turning")
              robot=right(opposite)
              spawner(robot)
              comm(robot,"turning")
              robot=right(robot)
              robot
            else
              {opposite,msg}=comm(opposite,"moving")
              if msg != "goal_exchange" or msg != "escaped" do
                returned=move(opposite)
                spawner(returned)
                decision=spawn_checker(returned,"right")
                if decision==true do
                  comm(returned,"turning")
                  robot=right(returned)
                  flag=spawner(robot)
                  if flag==true do
                    axis=@robot_map_facing_to_axis[robot.facing]
                    move_adjacent(robot,axis)
                  else
                    {robot,msg}=comm(robot,"moving")
                    if msg != "goal_exchange"  or msg != "escaped"do
                      robo=move(robot)
                      robo
                    else
                      robot
                    end
                  end
                else
                  comm(returned,"turning")
                  robot=left(returned)
                  flag=spawner(robot)
                  if flag==true do
                    axis=@robot_map_facing_to_axis[robot.facing]
                    move_adjacent(robot,axis)
                  else
                    {robot,msg}=comm(robot,"moving")
                    if msg != "goal_exchange" or msg != "escaped" do
                      robo=move(robot)
                      robo
                    else
                      robot
                    end
                  end
                end
              else
                opposite
              end
            end
          axis=='y' and robot.facing==:north and robot.x == 1 and right_bool==true or axis=='y' and  robot.facing== :south and robot.x == 6 and right_bool==true or
          axis=='x' and robot.facing==:east and @robot_map_y_atom_to_num[robot.y] == 6 and right_bool==true or axis=='x' and robot.facing== :west and
          @robot_map_y_atom_to_num[robot.y] == 1 and right_bool==true ->

            comm(right_robot,"turning")
            opposite=right(right_robot)
            doom=spawner(opposite)
            if doom==true or axis=='y' and robot.y==:a and robot.x==1 or axis=='y' and robot.y==:f and robot.x==6 or axis=='x' and robot.y==:f and robot.x==1 or axis=='x' and robot.y==:a and robot.x==6 do
              comm(opposite,"turning")
              robot=right(opposite)
              spawner(robot)
              comm(robot,"turning")
              robot=right(robot)
              robot
            else
              {opposite,msg}=comm(opposite,"moving")
              if msg != "goal_exchange" or msg != "escaped" do
                returned=move(opposite)
                spawner(returned)
                comm(returned,"turning")
                robot=left(returned)
                flag=spawner(robot)
                if flag == true do
                  axis=@robot_map_facing_to_axis[robot.facing]
                  move_adjacent(robot,axis)
                else
                  {robot,msg}=comm(robot,"moving")
                  if msg != "goal_exchange" or msg != "escaped" do
                    move(robot)
                  else
                    robot
                  end
                end
              else
                opposite
              end
            end

         true ->
          comm(right_robot,"turning")
          robot=left(right_robot)
          robot
        end
    end
  end



  def rotate_robot_x(robot, goal_x) do
    cond do
      goal_x > robot.x and robot.facing == :north -> right(robot)
      goal_x > robot.x and robot.facing==:south ->  left(robot)
      goal_x <= robot.x and robot.facing == :south -> right(robot)
      goal_x <= robot.x and robot.facing==:north -> left(robot)
      true -> right(robot)
    end
  end

  def rotate_robot_y(robot, goal_y) do
    cond do
      @robot_map_y_atom_to_num[goal_y] > @robot_map_y_atom_to_num[robot.y] and robot.facing == :east  -> left(robot)
      @robot_map_y_atom_to_num[goal_y] > @robot_map_y_atom_to_num[robot.y] and robot.facing == :west -> right(robot)
      @robot_map_y_atom_to_num[goal_y] <= @robot_map_y_atom_to_num[robot.y] and robot.facing==:east -> right(robot)
      @robot_map_y_atom_to_num[goal_y] <= @robot_map_y_atom_to_num[robot.y] and robot.facing == :west -> left(robot)
      true -> right(robot)
    end
  end

  @doc """
  Provides the report of the robot's current position

  Examples:

      iex> {:ok, robot} = Task4CClientRobotA.place(2, :b, :west)
      iex> Task4CClientRobotA.report(robot)
      {2, :b, :west}
  """
  def report(%Task4CClientRobotA.Position{x: x, y: y, facing: facing} = _robot) do
    {x, y, facing}
  end


  @directions_to_the_right %{north: :east, east: :south, south: :west, west: :north}
  @doc """
  Rotates the robot to the right
  """
  def right(%Task4CClientRobotA.Position{facing: facing} = robot) do
    Alphabot.turn(robot,:right)
    %Task4CClientRobotA.Position{robot | facing: @directions_to_the_right[facing]}
  end

  @directions_to_the_left Enum.map(@directions_to_the_right, fn {from, to} -> {to, from} end)
  @doc """
  Rotates the robot to the left
  """
  def left(%Task4CClientRobotA.Position{facing: facing} = robot) do
    Alphabot.turn(robot,:left)
    %Task4CClientRobotA.Position{robot | facing: @directions_to_the_left[facing]}
  end

  @doc """
  Moves the robot to the north, but prevents it to fall
  """
  def move(%Task4CClientRobotA.Position{x: _, y: y, facing: :north} = robot) when y < @table_top_y do
    Alphabot.move(robot)
    %Task4CClientRobotA.Position{ robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) + 1 end) |> elem(0)
    }
  end

  @doc """
  Moves the robot to the east, but prevents it to fall
  """
  def move(%Task4CClientRobotA.Position{x: x, y: _, facing: :east} = robot) when x < @table_top_x do
    Alphabot.move(robot)
    %Task4CClientRobotA.Position{robot | x: x + 1}
  end

  @doc """
  Moves the robot to the south, but prevents it to fall
  """
  def move(%Task4CClientRobotA.Position{x: _, y: y, facing: :south} = robot) when y > :a do
    Alphabot.move(robot)
    %Task4CClientRobotA.Position{ robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) - 1 end) |> elem(0)}
  end

  @doc """
  Moves the robot to the west, but prevents it to fall
  """
  def move(%Task4CClientRobotA.Position{x: x, y: _, facing: :west} = robot) when x > 1 do
    Alphabot.move(robot)
    %Task4CClientRobotA.Position{robot | x: x - 1}
  end

  @doc """
  Does not change the position of the robot.
  This function used as fallback if the robot cannot move outside the table
  """
  def move(robot), do: robot

  def failure do
    raise "Connection has been lost"
  end
end
