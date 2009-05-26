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

def rollin_initial(event, lists, actives)
  listname = event.attributes["list"]
  list = lists[listname]
  event.elements.each("roll") do |m|
    list.insert(m.attributes["value"].to_i - 1, m.attributes["player"])
  end
end

def rollin_to_active_list(event, lists, actives)
  listname = event.attributes["list"]
  list = lists[listname]

  event.elements.each("roll") do |m|
    player = m.attributes["player"]
    roll = m.attributes["value"].to_i
    sorted_actives = list.find_all { |x| actives.include? x }
    if roll == 1 then
      # insert before first active
      first_active = sorted_actives[0]
      list.insert(list.index(first_active), player)
    else
      # insert after select active
      active = sorted_actives[roll - 2]
      list.insert(list.index(active)+1, player)
    end
  end
end
