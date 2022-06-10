defmodule Alphabot do

  @moduledoc """

   This module contains various functions to operate the peripherals of the alphabot.
   The alphabot is using Raspberrypi as controller
   3 servos for 3 DOF Arm
   2 IR Sensors For obstacle detection as well as seed object detection.
   2 Motors to operate the wheels
   1  five array line tracker sensor

  """
  require Logger
  use Bitwise
  alias Circuits.GPIO

  @sensor_pins [cs: 5, clock: 25, address: 24, dataout: 23]
  @ir_pins [dr: 16, dl: 19]
  @motor_pins [lf: 12, lb: 13, rf: 20, rb: 21]
  @pwm_pins [{6, 0}, {26,1}]
  @servo_a_pin 27
  @servo_b_pin 22
  @servo_c_pin 17
  @pwm_frequency 50

  @ref_atoms [:cs, :clock, :address, :dataout]
  @lf_sensor_data %{sensor0: 0, sensor1: 0, sensor2: 0, sensor3: 0, sensor4: 0, sensor5: 0}
  @lf_sensor_map %{0 => :sensor0, 1 => :sensor1, 2 => :sensor2, 3 => :sensor3, 4 => :sensor4, 5 => :sensor5}

  @forward [0, 1, 1, 0]
  @backward [1, 0, 0, 1]
  @back_left [0,0,0,1]
  @back_right [1,0,0,0]
  @left [0, 1, 0, 0]
  @right [0, 0, 1, 0]
  @stop [0, 0, 0, 0]

  @duty_cycles [150, 70, 0]




  @doc """
     Stops the Alphabot when it receives stopping signal from the server.
  """
  def stop_signal(robot) do
    Task4CClientRobotA.PhoenixSocketClient.get_stop_signal(robot)
  end

  @doc """
     Slides the Weed Box to the Dumping Zone.
     Takes arguments `robot` and `side` which are robot info and direction of the dumping zone
     with respect to the robot's facing Direction.
  """
  def slide_box(robot,side) do
    servos(robot,90,30,0)
    if side == :left do
      base_servo robot,120
      base_servo robot,150
      lift_servo robot,55,500
      list = [120,100,50,30,60,90]
      Enum.each(list, fn angle -> base_servo robot,angle end)

    else
      base_servo robot,70
      base_servo robot,45
      lift_servo robot,55,1000
      list = [70,80,120,150,120,90]
      Enum.each(list, fn angle -> base_servo robot,angle)
    end
    lift_servo robot,30,1000
  end

  @doc """
     Operates the servos to Pick the Weed stalks from the plants and place them in
     container attached at the back.
     Takes arguments `robot` and `side` which are map containing robot info and
     direction of the weed stalk with respect to the robot's facing
  """
  def fetch(robot,side) do
    servos(90,30,0)
    grip_servo(robot,0)


    if side == :left do
      list = [80,70,50,30,10,0]
      Enum.each(list, fn angle ->
        base_servo(robot,angle)
      end )
    else
      list = [100,120,140,160,180]
      Enum.each(list, fn angle ->
        base_servo(robot,angle)
      end)
    end

    lift_servo robot,44 , 1000
    grip_servo robot,30
    grip_servo robot,90
    grip_servo robot,150
    grip_servo robot,180
    Process.sleep(1000)
    lift_servo robot,15,1000

    if side == :left do
      list = [30,50,70,90]
      Enum.each(list, fn angle ->

        base_servo(robot,angle)
        lift_servo robot,10,500
        Process.sleep(300)
      end)

    else
      list = [140,120,100,90]
      Enum.each(list, fn angle ->
        base_servo(robot,angle)
        lift_servo robot,10,500
        Process.sleep(300)
      end)
    end
    lift_servo robot,30,0
    grip_servo robot,0
  end


  @doc """
     Operates the servos and the ir sensor to drop a seed object inside plant cavity
     The Arm starts vibrating to drop the seed object.
     When the seed Object falls the IR sensor on the edge detects it and rotates the servo3
     to block the seeds to avoid excessive seed dispatch and the arm stop vibrating.
     Takes arguments `robot` and `side`.
  """
  def seed_sowing(robot,side) do
    servos(90,30,0)

    if side == :left do
      list = [80,70,50,30,10,0]
      Enum.each(list, fn angle ->
        base_servo(robot,angle)
      end )
    else
      list = [100,120,140,160,180]
      Enum.each(list, fn angle ->
        base_servo(robot,angle)
      end )
    end

    lift_servo(robot,35,1000)
    grip_servo(robot,75)
    Process.sleep(1000)
    pid  = spawn(fn -> vibrate(robot,40) end)
    Process.register(pid,:vibrate_servo)
    check_dispatch(robot)
    recentre_arm(robot,side)

  end

  @doc """
     Opearates the servos to bring back the arm in its mean position.
  """
  def recentre_arm(robot,side) do
    if side == :left do
      list = [0,10,30,50,70,80,90]
      Enum.each(list, fn angle ->
        base_servo(robot,angle)
      end )
    else
      list = [180,160,140,120,100,90]
      Enum.each(list, fn angle ->
        base_servo(robot,angle)
      end )
    end
  end

  @doc """
     Vibrates the Arm to drop seed object by changing the angle of rotaion by 30 degrees
     in short duration to imitate the action of vibrating.
  """
  def vibrate(robot,angle) do
    lift_servo(robot,angle + 30,0)
    Process.sleep(50)
    lift_servo(robot,angle,0)
    Process.sleep(100)
    vibrate(robot,angle)
  end

  @doc """
     Keeps the ir sensor active to detect the fall of the seed object from the arm. As soon as
     the seed ob ject falls this function exits.
  """
  def check_dispatch(robot) do
    [binary,_] = proximity_check()
    if binary == 1 do
      check_dispatch(robot)
    else
      grip_servo(robot,0)
      lift_servo(robot,25,0)
      Process.exit(Process.whereis(:vibrate_servo),:stop_vibration)
      Process.sleep 1000
    end
  end


  @doc """
     Uses the IR sensor at the Front of alphabot to detect the presensce of path obstacle.
     Returns Boolean value `True` or `False`.
  """
  def obs_status do
    [_,binary] = proximity_check()
    if binary == 1 do
      false
    else
      true
    end
  end




     #Checks the presence of the objects in front of ir sensors.
     #Returns binary values in a list
  defp proximity_check do
    ir_ref = Enum.map(@ir_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :input, pull_mode: :pullup) end)
    ir_values = Enum.map(ir_ref,fn {_, ref_no} -> GPIO.read(ref_no) end)
  end


  @doc """
     Rotates the servo motors to their angular positions
     takes arguments
      `robot` -> Map containing Alphabot's Position
      `a`     -> Angular Postion for servo a which rotates the Base of the Arm ( Rotation Around X axis )
      `b`     -> Angular Postion for servo a which moves the Arm up or down ( Rotation around Y Axis )
      `c`     -> Angular Postion for servo a which rotates the stopper of the Arm to avoid seeds from falling ( Rotation around Z Axis )
  """
  def servos(robot,a,b,c) do
    lift_servo(robot,b,500)
    base_servo(robot,a)
    grip_servo(robot,c)
  end



    #Function to rotate servo motor B to move the arm up or down

  defp lift_servo(robot,angle,time) do
    stop_signal(robot)
    low_thresh = 10
    #Logger.debug("Testing Servo A")
    angle=if angle < low_thresh do
      angle = low_thresh
    else
      angle
    end
    IO.puts(angle)
    val = trunc(((2.5 + 10.0 * angle / 180) / 100 ) * 255)
    Pigpiox.Pwm.set_pwm_frequency(@servo_a_pin, @pwm_frequency)
    Pigpiox.Pwm.gpio_pwm(@servo_a_pin, val)
    Process.sleep(time)
  end


    ##Used to rotate the Servo Motor C which is used to grip the plant stalks as well as block the seed objects.

  defp grip_servo(robot,angle) do
    stop_signal(robot)
    high_thresh = 140
    angle = if angle > 135 do
      angle = 135
    else
      angle
    end
    val = trunc(((2.5 + 10.0 * angle / 180) / 100 ) * 255)
    Pigpiox.Pwm.set_pwm_frequency(@servo_b_pin, @pwm_frequency)
    Pigpiox.Pwm.gpio_pwm(@servo_b_pin, val)
    Process.sleep(0)
  end


    #Rotates the Base Servo motor.


  defp base_servo(robot,angle) do
    stop_signal robot
    val = trunc(((2.5 + 10.0 * angle / 180) / 100 ) * 255)
    Pigpiox.Pwm.set_pwm_frequency(@servo_c_pin, @pwm_frequency)
    Pigpiox.Pwm.gpio_pwm(@servo_c_pin, val)
    Process.sleep(500)
  end

  @doc """
     Turns the Alphabot in the direction given as argument `side`.
  """
  def turn(robot,side) do
    pid = Process.whereis(:starter)
    if pid != nil do
      send(:starter,:die)
    else
      :ok
    end
    servos(robot,90,30,0)
    pid = self()
    send(:robot_status,{:give_status,:PID,pid})
    status = receive do
      {:status, status} ->
        status
    end
    adjust_robot(robot,status)
    if side == :right do
      take_right(robot,150)
    else
      take_left(robot,150)
    end
    send(:robot_status,{:update_status,:turned,:PID,pid})
    receive do
      :ok_done ->
        :ok
    end
  end


     ##Turns the alphabot to the left side.

  defp take_left(robot,n) do
    stop_signal(robot)
    n = if n > 50 do
      n
    else
      50
    end
    IO.puts(n)
    left(:forward,200,n)
    [IR_ext_left: ir1,IR_left: ir2,IR_centre: ir3,IR_right: ir4,IR_ext_right: ir5] = give_path_values()
    if ir3 >= 950 do
      :ok_done
      recentre(:forward)
      stop
    else
      take_left(robot,n - 10)
    end
  end


     ##Turns the Alphabot to the right side.


  defp take_right(robot,n) do
    stop_signal(robot)
    pid=self()
    n = if n > 50 do
      n
    else
      50
    end
    IO.puts(n)
    right(:forward,200,n)
    [IR_ext_left: ir1,IR_left: ir2,IR_centre: ir3,IR_right: ir4,IR_ext_right: ir5] = give_path_values()
    if ir3 >= 950 do
      :ok_done
      recentre(:forward)
      stop

    else
      take_right(robot,n - 10)
    end
  end



     ###Turns the robot to left by providing duty cycle to the desired motors

  defp left(direction,duty,time) do
    if direction == :forward do
      motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
      motor_action(motor_ref, @left,time)
      Enum.each(@pwm_pins, fn {pin_no,_duty_num} -> Pigpiox.Pwm.gpio_pwm(pin_no, duty) end )
      motor_action(motor_ref,@stop,10)
    else
      motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
      motor_action(motor_ref, @back_left,time)
      Enum.each(@pwm_pins, fn {pin_no,_duty_num} -> Pigpiox.Pwm.gpio_pwm(pin_no, duty) end )
      motor_action(motor_ref,@stop,5)
    end

  end


  defp right(direction,duty,time) do
    if direction == :forward do
      motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
      motor_action(motor_ref, @right,time)
      Enum.each(@pwm_pins, fn {pin_no,_duty_num} -> Pigpiox.Pwm.gpio_pwm(pin_no, duty) end )
      motor_action(motor_ref,@stop,10)
    else
      motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
      motor_action(motor_ref, @back_right,time)
      Enum.each(@pwm_pins, fn {pin_no,_duty_num} -> Pigpiox.Pwm.gpio_pwm(pin_no, duty) end )
      motor_action(motor_ref,@stop,5)
    end
  end




  defp spawner do # Spawns the PID Controller Function
    align = calibrate
    align = if align == [0,0,0,0,0] do
      [0,0,1,0,0]
    else
      align
    end
    pid = spawn(fn -> pid_controller(0,align) end)
    Process.register(pid,:PID_controller)
    pid
  end

  defp starter do
    receive do
      _ -> :ok
    end
  end

  @doc """
     To move the alphabot from current node to to node ahead of it.
  """
  def move(robot) do
    ppid=spawner
    servos(robot,90,30,0)
    bool = if Process.whereis(:starter) != nil do
      send(:starter,:exit)
      true
    else
      false
    end
    pid=self()
    send(:robot_status,{:give_status,:PID,pid})
    status=receive do
      {:status,status} -> status
    end
    cond do
      status == :turned ->
        pd_moving(false)
      status == :unturned ->
        pd_moving(true)
    end
  end

  defp pd_moving(start) do
    start = if start == true  do
      for 1..5 do
        spid = self
        send(:pd_feedback,:duties,{:present_duties,[80,80],:my_pid,spid})
        duties = receive do
          {:duty_errors,duties} ->
            duties
        end
        forward(duties,15)
        false
      else
        start
      end
    end
    spid = self
    send(:pd_feedback,:duties,{:present_duties,[80,80],:my_pid,spid})
    duites = receive do
      {:duty_errors,duties} ->
        duties
    end
    forward(duties,15)
    alignment = calibrate
    if alignment == [1,1,1,1,1] or [ir_1,ir_2,ir_3] == [1,1,1] or [ir_3,ir_4,ir_5] == [1,1,1] or alignment == [0,1,1,1,0] do
      stop
      IO.puts(:on_a_node)
    else
      pd_moving(start)
    end
  end


## to move the robot in small steps especially while taking turns
  defp steps(robot,direction,duty,time) do
    stop_signal(robot)
    time = if time > 60  do
      time
    else
      60
    end
    node_status = recentre(direction)
    if node_status == :on_a_node do
      IO.puts(:on_the_node)
    else
      duties= [duty,duty]
      if direction == :forward do
        forward duties, time
      else
        backward duties, time
      end
      stop
      steps robot,direction ,duty,(time - 10)
    end
  end

  ## PID controller function for the alphabot to keep the alphabot on track using the five channel line tracker sensor

  defp pid_control(last_p_error,last_location) do
    receive do
      {:present_duties,[duty,duty],:my_pid,spid} ->
        values=calibrate()

        [value1,value2,value3,value4,value5] = if values == [0,0,0,0,0] do
          last_location
        else
          values
        end
        n = (0*value1 + 1000*value2 + 2000*value3 + 3000*value4 + 4000*value5)/(value1 + value2 + value3 + value4 + value5)
        [kp,kd]=[0.04,0.0001]
        p_error = (n - 2000)
        d_error = p_error - last_p_error
        last_p_error=p_error
        #last_i_error = i_error
        duty_error=kp*p_error + kd*d_error
        if duty_error < 0 do
          duty_error = (-1)*duty_error
          duties=[round(duty+duty_error),duty]
          send(spid,{:duty_errors,duties})
        else
          duties=[duty,round(duty+duty_error)]
          send(spid,{:duty_errors,duties})
        end
        last_location= if values == [1,1,1,1,1] or [value1,value2,value3] == [1,1,1] or [value3,value4,value5] == [1,1,1] or values == [0,1,1,1,0] do
          last_location
        else
          [value1,value2,value3,value4,value5]
        end
        pid_control(last_p_error,last_location)
    end
  end

## Recentres the robot back on track while moving in steps.
  def recentre(direction) do
    alignment = calibrate

    IO.inspect(alignment)
    [ir_1,ir_2,ir_3,ir_4,ir_5] = if alignment == [0,0,0,0,0] do
      [0,0,1,0,0]
    else
      alignment
    end
    position = (ir_1*0 + ir_2*1000 + ir_3*2000 + ir_4*3000+ ir_5*4000 )/(ir_1 + ir_2 + ir_3 + ir_4 + ir_5)
    IO.inspect(position)
    IO.puts("the sensor values are #{alignment} and position is #{position} ")
    cond do
      alignment == [1,1,1,1,1] or [ir_1,ir_2,ir_3] == [1,1,1] or [ir_3,ir_4,ir_5] == [1,1,1] or alignment == [0,1,1,1,0]->
        :on_a_node
      position == 2000 and alignment == [0,0,1,0,0] ->
        :on_track
      true ->
        cond do
          position > 2000  ->
            right(direction,180,40)
            recentre(direction)
          position < 2000 ->
            left(direction,180,40)
            recentre(direction)
          true ->
            :on_track
        end
    end
  end
## Helps to adjust the robot before turning the Alphabot
  defp adjust_robot(robot,status) do
    if status == :turned do
      for i <- 1..8 do
        stop_signal(robot)
        backward [140,140], 55
        stop()
        recentre(:backward)
      end
      :ok_ready
    else
      for i <- 1..5 do
        stop_signal(robot)
        forward [140,140], 53
        stop
        recentre(:forward)
      end
      :ok_ready
    end
  end

  @doc """
     Calibriton of Line tracker sensor Values by assigning them binary values to depict the color of surface underneath in it using a threshold value
     return either 1 or 0
     1 -> White line
     0 -> Black Line
  """
  def calibrate do

      [IR_ext_left: ir_1,IR_left: ir_2,IR_centre: ir_3,IR_right: ir_4,IR_ext_right: ir_5]=give_path_values()
      ir2 = ir_2
    #ir1_norm=((ir_1 - ir1_min)/(ir1_max - ir1_min))*1000
    thresh = 930
    ir_2 = if ir_2 > thresh do
      ir_2 = 1
    else
      ir_2 = 0
    end

    ir_3 = if ir_3 > thresh do
      ir_3 = 1
    else
      ir_3 = 0
    end

    ir_4 = if ir_4 > thresh do
      ir_4 = 1
    else
      ir_4 = 0
    end

    ir_5 = if ir_5 > thresh do
      ir_5 = 1
    else
      ir_5 = 0
    end

    ir_1 = if ir_1 >= 690 and ir_2 ==1 and ir_3 == 1 or ir2 >= 630 and ir_3 == 0 and ir_4 == 0 and ir_5 == 0 do
      ir_1 = 1
    else
      ir_1 = 0
    end

    values=[ir_1,ir_2,ir_3,ir_4,ir_5]
  end

  ## Move the alphabot forward with duty cycles given to the motors in the list `duties`.
  defp forward(duties,time) do
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    motor_action(motor_ref, @forward,time)
    Enum.each(@pwm_pins, fn {pin_no, duty_num} -> Pigpiox.Pwm.gpio_pwm(pin_no,Enum.at(duties,duty_num)) end)
  end

## moves the alphabot backward with duty cycles given to the motors in the list `duties`
  defp backward(duties,time) do
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    motor_action(motor_ref, @backward,time)
    Enum.each(@pwm_pins, fn {pin_no, duty_num} -> Pigpiox.Pwm.gpio_pwm(pin_no,Enum.at(duties,duty_num)) end)
  end

  @doc """
     Stops the robot by assigning 0 duty cycle to both tha motors
  """
  def stop do
    motor_ref = Enum.map(@motor_pins, fn {_atom, pin_no} -> GPIO.open(pin_no, :output) end)
    motor_action(motor_ref,@stop,1)
  end


  # This function keeps track of Robot's Position Whether on the node
  # When a robot Takes a turn It does not remain on the node
  # When a robot just takes a step ahead then It stops at the node

  defp robot_status(status) do
    receive do
      {:give_status,:PID,pid} ->
        if status == :turned do
          send(pid,{:status,status})
          robot_status(status)
        else
          send(pid,{:status, status})
          robot_status(status)
        end
      {:update_status,message,:PID,pid} ->
        if message== :turned do
          send(pid,:ok_done)
          robot_status(message)
        else
          send(pid,:ok_done)
          robot_status(message)
        end
    end

  end



 """
 helper function motor_action to operate the motor for the given duration duty cycle and selection of pins
 """
  defp motor_action(motor_ref,motion,time) do
    motor_ref |> Enum.zip(motion) |> Enum.each(fn {{_, ref_no}, value} -> GPIO.write(ref_no, value) end)
    Process.sleep(time)
  end

  """
  functions to obtain the values from the five channel ir sensor module for white line tracking
  """

  defp give_path_values do
    sensor_ref = Enum.map(@sensor_pins, fn {atom, pin_no} -> configure_sensor({atom, pin_no}) end)
    sensor_ref = Enum.map(sensor_ref, fn{_atom, ref_id} -> ref_id end)
    sensor_ref = Enum.zip(@ref_atoms, sensor_ref)
    values=get_lfa_readings([1,2,3,4,5], sensor_ref)
    values
  end
  """
  Helper function for
  """

  defp configure_sensor({atom, pin_no}) do
    if (atom == :dataout) do
      GPIO.open(pin_no, :input, pull_mode: :pullup)
    else
      GPIO.open(pin_no, :output)
    end
  end

  defp get_lfa_readings(sensor_list, sensor_ref) do
    append_sensor_list = sensor_list ++ [5]
    temp_sensor_list = [5 | append_sensor_list]
    values=append_sensor_list
    |> Enum.with_index
    |> Enum.map(fn {sens_num, sens_idx} ->
          analog_read(sens_num, sensor_ref, Enum.fetch(temp_sensor_list, sens_idx))
          end)
    [null,ir2,ir3,ir4,ir5,ir1]=values
    values=[IR_ext_left: ir1,IR_left: ir2,IR_centre: ir3,IR_right: ir4,IR_ext_right: ir5]
    Enum.each(0..5, fn n -> provide_clock(sensor_ref) end)
    GPIO.write(sensor_ref[:cs], 1)
    Process.sleep(250)
    values
  end


  defp analog_read(sens_num, sensor_ref, {_, sensor_atom_num}) do

    GPIO.write(sensor_ref[:cs], 0)
    %{^sensor_atom_num => sensor_atom} = @lf_sensor_map
    Enum.reduce(0..9, @lf_sensor_data, fn n, acc ->
                                          read_data(n, acc, sens_num, sensor_ref, sensor_atom_num)
                                          |> clock_signal(n, sensor_ref)
                                        end)[sensor_atom]
  end


  defp read_data(n, acc, sens_num, sensor_ref,sensor_atom_num) do
    if (n < 4) do

      if (((sens_num) >>> (3 - n)) &&& 0x01) == 1 do
        GPIO.write(sensor_ref[:address], 1)
      else
        GPIO.write(sensor_ref[:address], 0)
      end
      Process.sleep(1)
    end

    %{^sensor_atom_num => sensor_atom} = @lf_sensor_map
    if (n <= 9) do
      Map.update!(acc, sensor_atom, fn sensor_atom -> ( sensor_atom <<< 1 ||| GPIO.read(sensor_ref[:dataout]) ) end)
    end
  end

  defp provide_clock(sensor_ref) do
    GPIO.write(sensor_ref[:clock], 1)
    GPIO.write(sensor_ref[:clock], 0)
  end


  defp clock_signal(acc, n, sensor_ref) do
    GPIO.write(sensor_ref[:clock], 1)
    GPIO.write(sensor_ref[:clock], 0)
    acc
  end



end
