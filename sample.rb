# frozen_string_literal: true

require 'pycall/import'

# Pythonパッケージのインポート
module Py
  extend PyCall::Import
  pyimport('matplotlib.pyplot', as: :plt)
  pyimport('numpy', as: :np)
end

# 正の座標を表す
class Point
  attr_reader :x, :y

  def initialize(x_cor, y_cor)
    raise ArgumentError, '負の数は受け付けない' if x_cor.negative? || y_cor.negative?

    @x = x_cor
    @y = y_cor
  end

  def ==(other)
    x == other.x && y == other.y
  end
end

# 壁を表現する
class Wall
  attr_reader :point1, :point2

  def initialize(point1, point2)
    @point1 = point1.freeze
    @point2 = point2.freeze
  end

  def xs
    [@point1.x, @point2.x]
  end

  def ys
    [@point1.y, @point2.y]
  end

  def leftward?
    @point1.x > @point2.x
  end

  def rightward?
    @point1.x < @point2.x
  end

  def downward?
    @point1.y < @point2.y
  end

  def upward?
    @point1.y > @point2.y
  end

  def horizontal?
    @point1.y == @point2.y
  end

  def vertical?
    @point1.x == @point.x
  end

  def ==(other)
    @point1 == other.point1 && @point2 == other.point2
  end

  def reflect!(inplaced_value, value, pre_value, x_indice, y_indices)
    raise NotImplementedError, 'このメソッドを継承してオーバライドする必要がある'
  end
end

# 右壁
class RightWall < Wall
  def reflect!(inplaced_value, value, pre_value, x_indice, y_indices); end
end

# 左壁
class LeftWall < Wall
  def reflect!(inplaced_value, value, pre_value, x_indice, y_indices); end
end

# 上壁
class TopWall < Wall
  def reflect!(inplaced_value, value, pre_value, x_indice, y_indices); end
end

# 下壁
class BottomWall < Wall
  def reflect!(inplaced_value, value, pre_value, x_indice, y_indices); end
end

# 角
class CornerWall
  def initialize(point)
    @point = point.freeze
  end

  def reflect!(inplaced_value, value, pre_value, x_indice, y_indices)
    raise NotImplementedError, 'このメソッドを継承してオーバライドする必要がある'
  end
end

# 右上
class RightTopCorner < CornerWall
  def reflect!(inplaced_value, value, pre_value, x_indice, y_indices); end
end

# 左上
class LeftTopCorner < CornerWall
  def reflect!(inplaced_value, value, pre_value, x_indice, y_indices); end
end

# 右下
class RightBottomCorner < CornerWall
  def reflect!(inplaced_value, value, pre_value, x_indice, y_indices); end
end

# 左下
class LeftBottomCorner < CornerWall
  def reflect!(inplaced_value, value, pre_value, x_indice, y_indices); end
end

# 障害物
class Obstacle
  def initialize(walls, wave_pass_through: true)
    @walls = walls.freeze
    @corners = get_corners(wave_pass_through: wave_pass_through).freeze
  end

  def xs
    @walls.map(&:xs).flatten
  end

  def ys
    @walls.map(&:ys).flatten
  end

  def each_wall(&block)
    @walls.each(&block)
  end

  def each_corner(&block)
    @corners.each(&block)
  end

  private

  def get_corners(wave_pass_through: true)
    loop_walls = @walls + [@walls[0]]
    loop_walls.each_cons(2).each_with_object([]) do |(wall, next_wall), collection|
      corner = if wave_pass_through
                 get_internal_corner(wall, next_wall)
               else
                 get_external_corner(wall, next_wall)
               end
      next unless corner

      collection << corner.freeze
    end
  end

  def get_internal_corner(wall, wall2)
    return RightTopCorner.new(wall.point2) if wall.rightward? && wall2.downward?
    return RightBottomCorner.new(wall.point2) if wall.downward? && wall2.leftward?
    return LeftTopCorner.new(wall.point2) if wall.upward? && wall2.rightward?
    return LeftBottomCorner.new(wall.point2) if wall.leftward? && wall2.upward?

    nil
  end

  def get_external_corner(wall, wall2)
    return RightTopCorner.new(wall.point2) if wall.upward? && wall2.leftward?
    return RightBottomCorner.new(wall.point2) if wall.rightward? && wall2.upward?
    return LeftTopCorner.new(wall.point2) if wall.leftward? && wall2.downward?
    return LeftBottomCorner.new(wall.point2) if wall.downward? && wall2.rightward?

    nil
  end
end

# 格子
class Grid
  attr_reader :side, :width, :height

  def initialize(width, height, side)
    @width = width
    @height = height
    @side = side
  end

  def calculate_grid_num(num)
    (num / @side).floor
  end

  def row_num
    calculate_grid_num @width
  end

  def col_num
    calculate_grid_num @height
  end

  def wall_indices(wall)
    if wall.horizontal?
      xmin, xmax = wall.xs.sort.map { |cor| calculate_grid_num(cor) }
      x_indices = (xmin...xmax).to_a
      y = wall.ys[0]
      y_indices = [y] * x_indices.length
    else
      ymin, ymax = wall.ys.sort.map { |cor| calculate_grid_num(cor) }
      y_indices = (ymin...ymax).to_a
      x = wall.xs[0]
      x_indices = [x] * y_indices.length
    end
    [x_indices, y_indices]
  end

  def corner_index(corner)
    x_index = calculate_grid_num(corner.point.x)
    y_index = calculate_grid_num(corner.point.y)

    [x_index, y_index]
  end
end

# 波を作成するクラス
class WaveFactory
  def initialize(obstacles, h, dt)
    raise ArgumentError, 'クーラン条件に基づき. 格子幅hは変化時間dtより大きくすること. ' if dt > h

    x_max = obstacles.map(&:xs).flatten.max
    y_max = obstacles.map(&:ys).flatten.max

    @grid = Grid.new(x_max, y_max, h)
    @obstacles = obstacles
    @dt = dt
    @wave_value = Py.np.zeros([@grid.row_num, @grid.col_num])
    @pre_wave_value = Py.np.zeros([@grid.row_num, @grid.col_num])
  end

  def create
    value_r = Py.np.roll(@wave_value, -1, 1)
    value_l = Py.np.roll(@wave_value, 1, 1)
    value_b = Py.np.roll(@wave_value, -1, 0)
    value_t = Py.np.roll(@wave_value, 1, 0)
    new_value = 2 * @wave_value - @pre_wave_value + alpha * (value_l + value_r + value_b + value_t - 4 * @wave_value)
    @obstacles.each do |obstacle|
      obstacle.each_wall { |wall| wall.reflect!(new_value, @wave_value, @pre_wave_value, *@grid.wall_indices(wall)) }
      obstacle.each_corner do |corner|
        corner.reflect!(new_value, @wave_value, @pre_wave_value, *@grid.corner_index(corner))
      end
    end
    Wave.new(new_value.freeze)
    @pre_wave_value = @wave_value.freeze
    @wave_value = new_value.freeze
  end

  private

  def alpha
    te (@dt / @grid.side)**2
  end
end

# 波
class Wave
  attr_reader :value

  def initialize(value)
    @value = value.freeze
  end
end

point1 = Point.new(0, 0)
point2 = Point.new(5, 0)
point3 = Point.new(5, 5)
point4 = Point.new(0, 5)

p_1 = Point.new(1, 2)
p_2 = Point.new(2, 2)
p_3 = Point.new(2, 1)
p_4 = Point.new(3, 1)
p_5 = Point.new(3, 2)
p_6 = Point.new(4, 2)
p_7 = Point.new(4, 3)
p_8 = Point.new(3, 3)
p_9 = Point.new(3, 4)
p_10 = Point.new(2, 4)
p_11 = Point.new(2, 3)
p_12 = Point.new(1, 3)
p_13 = Point.new(1, 2)

wall_list = [TopWall.new(point1, point2), RightWall.new(point2, point3), BottomWall.new(point3, point4),
             LeftWall.new(point4, point1)]
obstacle = Obstacle.new(wall_list)

wall_list2 = [TopWall.new(p_1, p_2), LeftWall.new(p_2, p_3), TopWall.new(p_3, p_4), RightWall.new(p_4, p_5),
              TopWall.new(p_5, p_6), LeftWall.new(p_6, p_7), BottomWall.new(p_7, p_8), LeftWall.new(p_8, p_9),
              BottomWall.new(p_9, p_10), RightWall.new(p_10, p_11), BottomWall.new(p_11, p_12), LeftWall.new(p_12, p_13)]
obstacle2 = Obstacle.new(wall_list2, wave_pass_through: false)

obstacles = [obstacle, obstacle2]

wavefactory = WaveFactory.new(obstacles, 0.01, 0.005)
wavefactory.create
