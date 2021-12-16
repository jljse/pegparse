
module Pegparse
  BorrowedArea = Struct.new(
    :marker_pos,
    :start_pos,
    :end_pos,
    keyword_init: true,
  )
end

class Pegparse::BorrowedAreas
  def initialize
    @areas = []
  end

  def add_area(area)
    @areas << area
  end

  def conflicted_area(pos)
    conflicted = @areas.find{|area| area.start_pos <= pos && pos < area.end_pos }
  end

  def backtracked(pos)
    @areas.reject!{|area| area.marker_pos > pos }
  end

  def borrowed_area_start_pos
    @areas.first ? @areas.first.start_pos : nil
  end

  def borrowed_area_end_pos
    @areas.last ? @areas.last.end_pos : nil
  end
end
