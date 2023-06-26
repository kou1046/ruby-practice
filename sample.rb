# frozen_string_literal: true

require 'pycall/import'

# Pythonパッケージのインポート
module Py
  extend PyCall::Import
  pyimport('matplotlib.pyplot', as: :plt)
end

# 正の座標を表す
class Point
  attr_accessor :x, :y

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
  attr_accessor :point1, :point2

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

  def reflect!
    raise NotImplementedError, 'このメソッドを継承してオーバライドする必要がある'
  end
end

# 右壁
class RightWall < Wall
  def reflect!
    puts 'sample'
  end
end

# 左壁
class LeftWall < Wall
  def reflect!; end
end

# 上壁
class TopWall < Wall
  def reflect!; end
end

# 下壁
class BottomWall < Wall
  def reflect!; end
end

# 角
class CornerWall
  def initialize(point)
    @point = point.freeze
  end

  def xs
    [@point.x]
  end

  def ys
    [@point.y]
  end

  def reflect!
    raise NotImplementedError, 'このメソッドを継承してオーバライドする必要がある'
  end
end

# 右上
class RightTopCorner < CornerWall
  def reflect!; end
end

# 左上
class LeftTopCorner < CornerWall
  def reflect!; end
end

# 右下
class RightBottomCorner < CornerWall
  def reflect!; end
end

# 左下
class LeftBottomCorner < CornerWall
  def reflect!; end
end

# 障害物
class Obstacle
  include Enumerable

  def initialize(walls, wave_pass_through: true)
    @walls = initialize_(walls, wave_pass_through: wave_pass_through).freeze
  end

  def xs
    @walls.map(&:xs).flatten
  end

  def ys
    @walls.map(&:ys).flatten
  end

  def each(&block)
    @walls.each(&block)
  end

  private

  def initialize_(walls, wave_pass_through: true)
    loop_walls = walls + [walls[0]]
    loop_walls.each_cons(2).each_with_object([]) do |(wall, next_wall), collection|
      collection << wall.freeze
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
  def initialize(width, height, grid_side)
    @width = width
    @height = height
    @grid_side = grid_side
  end

  def calculate_grid_num(num)
    (num / @grid_side).floor
  end

  def row_num
    calculate_grid_num @width
  end

  def col_num
    calculate_grid_num @height
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
  end

  def create; end
end

# 波
class Wave
  def initialize; end
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
