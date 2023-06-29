require 'pycall/import'
require_relative 'domain'

# Pythonパッケージのインポート
module Py
  extend PyCall::Import
  pyimport('matplotlib.pyplot', as: :plt)
  pyimport('matplotlib.animation', as: :anim)
  pyimport('numpy', as: :np)
end

# 入力がある左壁
class StrainLeftWall < Wall
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
    time < 0.3 ? Py.np.cos(2 * Py.np.pi * time) : 0
  end
end

# 右の入力
class StrainRightWall < Wall
  def reflect!(value, pre_value, x, y, grid, time)
    2 * value[x,
              y] - pre_value[x,
                             y] + grid.alpha * (value[x - 1,
                                                      y] + value[x,
                                                                 y + 1] + value[x,
                                                                                y - 1] - 4 * value[x,
                                                                                                   y] - 2 * grid.side * input(time))
  end

  def input(time)
    time < 0.3 ? Py.np.cos(2 * Py.np.pi * time) : 0
  end
end

width = 5.0
height = 5.0
h = 0.02
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

wall_list3 = [StrainLeftWall.new(Point.new(0, 2.0), Point.new(0, 4.0))]

obstacle2 = Obstacle.new(wall_list2, wave_pass_through: false)
obstacle3 = Obstacle.new(wall_list3, wave_pass_through: true)
obstacles = [obstacle, obstacle2, obstacle3]
wavefactory = WaveFactory.new(grid, obstacles)

fig, ax = Py.plt.subplots
obstacles.each { |obs| ax.plot(obs.xs, obs.ys, color: :k) }

times = Py.np.arange(0, 5, dt)
ims = []

(0...times.size).each do |_i|
  wave = wavefactory.create
  im = ax.imshow(wave.value.T, cmap: 'binary', extent: [0, 5, 0, 5], vmin: -0.01, vmax: 0.01, origin: 'lower')
  ims << [im]
end

anim.save('sample.gif')
