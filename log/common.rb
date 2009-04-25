def suicide(actives, list, player)
  drag_source = list.index(player)
  drag_source.upto(list.length-1) do |i|
    if actives.include? list[i]
      tmp = list[drag_source]
      list[drag_source] = list[i]
      list[i] = tmp
      drag_source = i
    end
  end
  list
end
