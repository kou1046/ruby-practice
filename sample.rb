# frozen_string_literal: true

require 'pycall/import'

module Py
  extend PyCall::Import
  pyimport('math')
end

module Location
  LEFT = 0
  RIGHT = 1
  TOP = 2
  BOTTOM = 3
  RIGHTTOP = 4
  LEFTTOP = 5
  RIGHTBOTTOM = 6
  LEFTBOTTOM = 7
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

  def leftward?
    @point1.x > @point2.x
  end

  def rightward?
    !leftward?
  end

  def downward?
    @point1.y > @point2.y
  end

  def upward?
    !downward?
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

# Wallのドメインサービス
class WallService
  def get_internal_corner(wall, wall2)
    return RightTopCorner.new(wall.point2) if wall.rightward? && wall2.downward?
    return RightBottomCorner.new(wall.point2) if wall.downward? && wall2.leftward?
    return LeftTopCorner.new(wall.point2) if wall.upward? && wall2.rightward?
    return LeftBottomCorner.new(wall.point2) if wall.leftward? && wall2.upward?
  end

  def get_external_corder(_wall, _wall2)
    puts 'sample'
  end
end

# 右壁
class RightWall < Wall
  def reflect!
    puts 'sample'
  end
end

# 左壁
class Leftwall < Wall
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
    @point = point
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
  def initialize(walls, wave_pass_through: true)
    @wall_service = WallService.new
    @walls = _initialize walls, wave_pass_through: wave_pass_through
  end

  private

  def _initialize(walls, wave_pass_through: true)
    return unless wave_pass_through

    walls.each_cons(2).each_with_object([]) do |(wall, next_wall), collection|
      collection.push(wall)
      collection.push(@wall_service.get_internal_corner(wall, next_wall))
    end
  end
end

point1 = Point.new(0, 0)
point2 = Point.new(5, 0)
point3 = Point.new(5, 5)
point4 = Point.new(0, 5)

wall_list = [Wall.new(point1, point2), Wall.new(point2, point3), Wall.new(point3, point4), Wall.new(point4, point1)]

obstacle = Obstacle.new(wall_list)
