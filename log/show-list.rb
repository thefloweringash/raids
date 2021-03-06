require 'rexml/document'

require 'common'

lists = {}
actives = []
lookaside = {}
seen_rule_changes = {}
rollin_function = :rollin_initial

ARGV.each do |raidfile|
  raiddoc = REXML::Document.new(File.new(raidfile))

  raid = raiddoc.elements[1]

  raiddoc.elements.each("raid/*") do |event|
    case event.name
    when "roster"
      actives = []
      event.elements.each("player") do |p|
        name = p.attributes["name"]
        slot = p.attributes["using-slot-of"] || name
        if slot != name
          lookaside[name] = slot
        end
        actives << slot
      end

    when "initial-roll-in"
      listname = event.attributes["list"]
      list = lists[listname] = []
      event.elements.each("roll") do |m|
        list << m.attributes["player"]
      end

    when "boss", "trash"
      event.elements.each("loot") do |l|
        l.elements.each("assigned") do |assignment|
          listname = assignment.attributes["list"]
          list = lists[listname]
          player = assignment.attributes["player"]
          if lookaside[player]
            player = lookaside[player]
          end
          suicide(actives, list, player)
        end
      end

    when "roll-in"
      send(rollin_function, event, lists, actives)

    when "rule-change"
      change_name = event.attributes["id"]

      if seen_rule_changes[change_name] then
        raise "The same rule change happened twice: #{change_name}"
      end
      seen_rule_changes[change_name] = true

      case change_name
      when "rollin-to-place-in-active-list"
        rollin_function = :rollin_to_active_list
      else
        raise "Unknown rule change: #{change_name}"
      end
    end
  end
end

lists.each do |name,players|
  puts "#{name}:"
  puts players.reject{|x| !actives.include? x}.join(", ")
end
