# frozen_string_literal: true

require 'pycall/import'

# Pythonパッケージのインポート
module Py
  extend PyCall::Import
  pyimport('matplotlib.pyplot', as: :plt)
  pyimport('matplotlib.animation', as: :anim)
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

# 入力がある左壁
class StrainLeftWall < LeftWall
  def reflect!(value, pre_value, x, y, grid, time)
    2 * value[x,
              y] - pre_value[x,
                             y] + grid.alpha * (value[x + 1,
                                                      y] + value[x,
                                                                 y + 1] + value[x,
                                                                                y - 1] - 4 * value[x,
                                                                                                   y] - 2 * grid.side * input(time))
  end

  def input(time)
    time < 3 ? Py.np.cos(2 * Py.np.pi * time) : 0
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
    @walls.map(&:xs).flatten
  end

  def ys
    @walls.map(&:ys).flatten
  end

  def reflect!(inplaced_value, value, pre_value, grid, time)
    (@walls + [@walls[0]]).each_cons(2) do |wall, next_wall|
      xs, ys = grid.wall_indices(wall)
      corner = get_corner(wall, next_wall)
      if corner
        xs.delete_at(-1)
        ys.delete_at(-1)
        x, y = grid.corner_index(corner)
        inplaced_value[x, y] = corner.reflect!(value, pre_value, x, y, grid, time)
      end
      inplaced_value[xs, ys] = wall.reflect!(value, pre_value, Py.np.array(xs), Py.np.array(ys), grid, time)
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
    new_value = 2 * @wave_value - @pre_wave_value \
                + @grid.alpha * (value_l + value_r + value_b + value_t - 4 * @wave_value)

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

width = 5
height = 5
h = 0.05
dt = 0.01

grid = Grid.new(width, height, h, dt)

point1 = Point.new(0.0, 0.0)
point2 = Point.new(5.0, 0.0)
point3 = Point.new(5.0, 5.0)
point4 = Point.new(0.0, 5.0)

p_1 = Point.new(1.0, 2.0)
p_2 = Point.new(2.0, 2.0)
p_3 = Point.new(2.0, 1.0)
p_4 = Point.new(3.0, 1.0)
p_5 = Point.new(3.0, 2.0)
p_6 = Point.new(4.0, 2.0)
p_7 = Point.new(4.0, 3.0)
p_8 = Point.new(3.0, 3.0)
p_9 = Point.new(3.0, 4.0)
p_10 = Point.new(2.0, 4.0)
p_11 = Point.new(2.0, 3.0)
p_12 = Point.new(1.0, 3.0)
p_13 = Point.new(1.0, 2.0)

wall_list = [TopWall.new(point1, point2), RightWall.new(point2, point3), BottomWall.new(point3, point4),
             LeftWall.new(point4, point1)]
obstacle = Obstacle.new(wall_list)

wall_list2 = [BottomWall.new(p_1, p_2), RightWall.new(p_2, p_3), BottomWall.new(p_3, p_4), LeftWall.new(p_4, p_5),
              BottomWall.new(p_5, p_6), LeftWall.new(p_6, p_7), TopWall.new(p_7, p_8), LeftWall.new(p_8, p_9),
              TopWall.new(p_9, p_10), RightWall.new(p_10, p_11), TopWall.new(p_11, p_12), RightWall.new(p_12, p_13)]

wall_list3 = [StrainLeftWall.new(Point.new(0.0, 2.0), Point.new(0.0, 4.0))]

obstacle2 = Obstacle.new(wall_list2, wave_pass_through: false)
obstacle3 = Obstacle.new(wall_list3, wave_pass_through: true)
obstacles = [obstacle, obstacle2, obstacle3]

fig, ax = Py.plt.subplots
obstacles.each { |obs| ax.plot(obs.xs, obs.ys, color: :k) }
wavefactory = WaveFactory.new(grid, obstacles)

times = Py.np.arange(0, 10, dt)
ims = []

(0...times.size).each do |i|
  wave = wavefactory.create
  im = ax.imshow(wave.value.T, cmap: 'binary', extent: [0, 5, 0, 5], vmin: -0.01, vmax: 0.01, origin: 'lower')
  ims << [im]
end

anim = Py.anim.ArtistAnimation.new(fig, ims, interval: 60)
anim.save('sample.gif')
