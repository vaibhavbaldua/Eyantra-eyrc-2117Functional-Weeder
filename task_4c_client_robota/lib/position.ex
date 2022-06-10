defmodule Task4CClientRobotA.Position do
  defstruct x: 1, y: :a, facing: :north

  @table_top_x 6
  # max y-coordinate of table top
  @table_top_y :f
  # mapping of y-coordinates
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5, :f => 6}

 
end
