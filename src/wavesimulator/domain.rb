# frozen_string_literal: true

require 'pycall/import'

# Pythonパッケージのインポート
module Py
  extend PyCall::Import
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

  def reflect!(inplaced_value, value, pre_value, grid, time)
    raise NotImplementedError, 'このメソッドを継承してオーバライドする必要がある'
  end
end

# 右壁
class RightWall < Wall
  def reflect!(value, pre_value, x, y, grid, _time)
    2 * value[x,
              y] - pre_value[x,
                             y] + grid.alpha * (2 * value[x - 1,
                                                          y] + value[x, y - 1] + value[x, y + 1] - 4 * value[x, y])
  end
end

# 左壁
class LeftWall < Wall
  def reflect!(value, pre_value, x, y, grid, _time)
    2 * value[x,
              y] - pre_value[x,
                             y] + grid.alpha * (2 * value[x + 1,
                                                          y] + value[x, y - 1] + value[x, y + 1] - 4 * value[x, y])
  end
end

# 上壁
class TopWall < Wall
  def reflect!(value, pre_value, x, y, grid, _time)
    2 * value[x,
              y] - pre_value[x,
                             y] + grid.alpha * (value[x - 1,
                                                      y] + value[x + 1, y] + 2 * value[x, y + 1] - 4 * value[x, y])
  end
end

# 下壁
class BottomWall < Wall
  def reflect!(value, pre_value, x, y, grid, _time)
    2 * value[x,
              y] - pre_value[x,
                             y] + grid.alpha * (value[x - 1,
                                                      y] + value[x + 1, y] + 2 * value[x, y - 1] - 4 * value[x, y])
  end
end

# 角
class CornerWall
  attr_reader :point

  def initialize(point)
    @point = point.freeze
  end

  def reflect!(value, pre_value, x, y, grid, _time)
    raise NotImplementedError, 'このメソッドを継承してオーバライドする必要がある'
  end
end

# 右上
class RightTopCorner < CornerWall
  def reflect!(value, pre_value, x, y, grid, _time)
    2 * value[x, y] - pre_value[x, y] + grid.alpha * (2 * value[x - 1, y] + 2 * value[x, y + 1] - 4 * value[x, y])
  end
end

# 左上
class LeftTopCorner < CornerWall
  def reflect!(value, pre_value, x, y, grid, _time)
    2 * value[x, y] - pre_value[x, y] + grid.alpha * (2 * value[x + 1, y] + 2 * value[x, y + 1] - 4 * value[x, y])
  end
end

# 右下
class RightBottomCorner < CornerWall
  def reflect!(value, pre_value, x, y, grid, _time)
    2 * value[x, y] - pre_value[x, y] + grid.alpha * (2 * value[x - 1, y] + 2 * value[x, y - 1] - 4 * value[x, y])
  end
end

# 左下
class LeftBottomCorner < CornerWall
  def reflect!(value, pre_value, x, y, grid, _time)
    2 * value[x, y] - pre_value[x, y] + grid.alpha * (2 * value[x + 1, y] + 2 * value[x, y - 1] - 4 * value[x, y])
  end
end

# 障害物
class Obstacle
  def initialize(walls, wave_pass_through: true)
    @walls = walls.freeze
    @wave_pass_through = wave_pass_through
  end

  def xs
    @walls.map(&:xs)
  end

  def ys
    @walls.map(&:ys)
  end

  def wall_classes
    @walls.map { |wall| wall.class.name.to_sym }
  end

  def reflect!(inplaced_value, value, pre_value, grid, time)
    ([@walls[-1]] + @walls + [@walls[0]]).each_cons(3) do |prev_wall, wall, next_wall|
      xs, ys = grid.wall_indices(wall)
      prev_corner = get_corner(prev_wall, wall)
      next_corner = get_corner(wall, next_wall)
      if prev_corner
        xs.delete_at(0)
        ys.delete_at(0)
      end
      if next_corner
        xs.delete_at(-1)
        ys.delete_at(-1)
        x, y = grid.corner_index(next_corner)
        inplaced_value[x, y] = next_corner.reflect!(value, pre_value, x, y, grid, time)
        disable_internal_corner_reflecton(inplaced_value, wall, next_corner, x, y)
      end
      inplaced_value[xs, ys] = wall.reflect!(value, pre_value, Py.np.array(xs), Py.np.array(ys), grid, time)
      disable_internal_reflection(inplaced_value, wall, Py.np.array(xs), Py.np.array(ys))
    end
  end

  private

  def get_corner(wall, next_wall)
    if @wave_pass_through
      get_internal_corner(wall, next_wall)
    else
      get_external_corner(wall, next_wall)
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

  def disable_internal_reflection(inplaced_value, wall, x, y)
    return if @wave_pass_through

    inplaced_value[x - 1, y] = 0 if wall.downward?
    inplaced_value[x + 1, y] = 0 if wall.upward?
    inplaced_value[x, y - 1] = 0 if wall.leftward?
    inplaced_value[x, y + 1] = 0 if wall.rightward?
  end

  def disable_internal_corner_reflecton(inplaced_value, wall, corner, x, y)
    return if @wave_pass_through
    return unless corner

    inplaced_value[[x, x - 1], [y + 1, y]] = 0 if wall.downward? # 左下角
    inplaced_value[[x, x + 1], [y - 1, y]] = 0 if wall.upward? # 右上角
    inplaced_value[[x, x - 1], [y - 1, y]] = 0 if wall.leftward? # 左上角
    inplaced_value[[x, x + 1], [y + 1, y]] = 0 if wall.rightward? # 右上角
  end
end

# 格子
class Grid
  attr_reader :dt, :side, :width, :height

  def initialize(width, height, side, dt)
    raise ArgumentError, 'クーラン条件に基づき. 格子幅hは変化時間dtより大きくすること. ' if dt > side

    @width = width
    @height = height
    @side = side
    @dt = dt
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

  def alpha
    (@dt / @side)**2
  end

  def wall_indices(wall)
    if wall.horizontal?
      xmin, xmax = wall.xs.sort.map { |cor| calculate_grid_num(cor) }
      x_indices = (xmin...xmax).to_a
      y_index = calculate_grid_num(wall.ys[0])
      y_index -= 1 unless y_index.zero?
      y_indices = [y_index] * x_indices.length
    else
      ymin, ymax = wall.ys.sort.map { |cor| calculate_grid_num(cor) }
      y_indices = (ymin...ymax).to_a
      x_index = calculate_grid_num(wall.xs[0])
      x_index -= 1 unless x_index.zero?
      x_indices = [x_index] * y_indices.length
    end
    [x_indices, y_indices]
  end

  def corner_index(corner)
    x_index = calculate_grid_num(corner.point.x)
    y_index = calculate_grid_num(corner.point.y)

    x_index -= 1 unless x_index.zero?
    y_index -= 1 unless y_index.zero?

    [x_index, y_index]
  end
end

# 波を作成するクラス
class WaveFactory
  def initialize(grid, obstacles)
    @grid = grid
    @obstacles = obstacles
    @wave_value = Py.np.zeros([@grid.row_num, @grid.col_num])
    @pre_wave_value = Py.np.zeros([@grid.row_num, @grid.col_num])
    @time = 0
  end

  def create
    value_r, value_l, value_t, value_b = shift_value
    new_value = 2 * @wave_value - @pre_wave_value + @grid.alpha * (value_l + value_r + value_b + value_t - 4 * @wave_value)

    @obstacles.each { |obstacle| obstacle.reflect!(new_value, @wave_value, @pre_wave_value, @grid, @time) }

    update!(new_value.copy, @wave_value.copy)
    Wave.new(new_value.copy)
  end

  private

  def update!(new_wave_value, new_pre_wave_value)
    @wave_value = new_wave_value
    @pre_wave_value = new_pre_wave_value
    @time += @grid.dt
  end

  def shift_value
    [Py.np.roll(@wave_value, -1, 1), Py.np.roll(@wave_value, 1, 1),
     Py.np.roll(@wave_value, 1, 0), Py.np.roll(@wave_value, -1, 0)]
  end
end

# 波
class Wave
  attr_reader :value

  def initialize(value)
    @value = value
  end
end
