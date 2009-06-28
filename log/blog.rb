require 'erb'
require 'rexml/document'

require 'common'

module Templates
  def pp_player(lookaside, player)
    if lookaside[player]
      "#{lookaside[player]} (#{player})"
    else
      player
    end
  end
  module_function :pp_player
  Page = ERB.new(%q{
    <html>
      <head>
        <title><%= raid.attributes["name"] %> (<%= raid.attributes["mode"] %>)</title>
        <link rel="stylesheet" type="text/css" href="style.css"/>
      </head>
      <body>
        <script src="http://www.wowhead.com/widgets/power.js"></script>
        <%= event_stream %>
      </body>
    </html>
  },nil,nil,'_erbout_page')
  RaidStart = ERB.new(%q{
    <h1><a href="http://www.wowhead.com/?zone=<%= raid.attributes["id"] %>"
        ><%= raid.attributes["name"] %> (<%= raid.attributes["mode"] %>)</a></h1>
  },nil,nil,'_erbout_raidstart')
  Roster = ERB.new(%q{
    <h2>Roster</h2>
    <% if old_actives.empty? %>
      <ul>
        <% for p in actives %>
          <li><%= Templates::pp_player(lookaside_inverse, p) %></li>
        <% end %>
      </ul>
    <% else %>
      <ul>
        <% for p in old_actives.reject { |x| actives.include? x } %>
          <li class="player_left"><%= Templates::pp_player(lookaside_inverse, p) %></li>
        <% end %>
        <% for p in actives.reject { |x| old_actives.include? x } %>
          <li class="player_joined"><%= Templates::pp_player(lookaside_inverse, p) %></li>
        <% end %>
      </ul>
    <% end %>
  },nil,nil,'_erbout_roster')
  InitialRollin = ERB.new(%q{
    <p>List <%= listname %> rolled in</p>
    <%= Templates::PrettyList.result(binding) %>
  },nil,nil,'_erbout_initialrollin')
  Rollin =  ERB.new(%q{
    <p>List <%= listname %> added to</p>
    <%= Templates::PrettyList.result(binding) %>
  },nil,nil,'_erbout_rollin')
  PrettyList =  ERB.new(%q{
    <ul>
      <% for p in list %>
        <li><%= p %><% if !actives.include? p %> (inactive)<% end %></li>
      <% end %>
    </ul>
  },nil,nil,'_erbout_prettylist')
  DiffLists = ERB.new(%q{
    <% old_list = old_lists[changed_list] %>
    <% new_list = lists[changed_list] %>
    <table class="difflist" cellspacing="0">
      <tr>
        <th>Old</th>
        <th>New</th>
      </tr>
      <% for i in 0..new_list.length %>
        <tr>
          <% if old_list[i] == new_list[i] %>
            <td colspan="2" class="stationary <%= (actives.include? old_list[i]) ? "" : "inactive" %>"><%= old_list[i] %></td>
          <% else %>
            <td class="moved <%= (actives.include? old_list[i]) ? "" : "inactive" %>"><%= old_list[i] %></td>
            <td class="moved <%= (actives.include? new_list[i]) ? "" : "inactive" %>"><%= new_list[i] %></td>
          <% end %>
        </tr>
      <% end %>
    </table>
  },nil,nil,'_erbout_difflists')
  Drop = ERB.new(%q{
    <h2>Random drop</h2>
    <%= Templates::Loot.result(binding) %>
    <% for changed_list in changed_lists %>
       <%= Templates::DiffLists.result(binding) %>
    <% end %>
  },nil,nil,'_erbout_drop')
  BossDown = ERB.new(%q{
    <h2><a href="http://www.wowhead.com/?npc=<%= event.attributes["id"] %>"
         ><%= event.attributes["name"] %></a> down</h2>
    <%= Templates::Loot.result(binding) %>
    <% for changed_list in changed_lists %>
       <%= Templates::DiffLists.result(binding) %>
    <% end %>
  },nil,nil,'_erbout_bossdown')

  Loot = ERB.new(%q{
    <ul>
      <% for won in won_items %>
         <li><a href="http://www.wowhead.com/?item=<%= won[:item].attributes["id"]%>"
              ><%= won[:item].attributes["name"] %></a> won by
              <%= won[:assignment].attributes["player"] %>
             (<%= won[:assignment].attributes["list"] %>)
         </li>
      <% end %>
      <% for de in de_items %>
         <li><a href="http://www.wowhead.com/?item=<%= de[:item].attributes["id"]%>"
              ><%= de[:item].attributes["name"] %></a> DEd by <%= de[:de].attributes["player"] %></li>
      <% end %>
      <% for d in donated_items %>
         <li><a href="http://www.wowhead.com/?item=<%= d[:item].attributes["id"]%>"
              ><%= d[:item].attributes["name"] %></a> donated to <%= d[:donation].attributes["player"] %></li>
      <% end %>
    </ul>
  },nil,nil,'_erbout_loot')

  Comment = ERB.new(%q{<p><%= event.text %></p>},nil,nil,'_erbout_comment')
  RaidEnd = ERB.new(%q{
    <p><strong>Raid Ended: </strong><%= event.text %></p>
  },nil,nil,'_erbout_raidend')
  RuleChange = ERB.new(%q{
    <p><strong>Rule change: <%= event.attributes["id"] %></strong>.
       <%= event.text %></p>
  },nil,nil,'_erbout_rulechange');
end


lists = {}
seen_rule_changes = {}
rollin_function = :rollin_initial

ARGV.each do |raidfile|
  raiddoc = REXML::Document.new(File.new(raidfile))

  event_stream = ""
  raid = raiddoc.elements[1]
  actives = []
  lookaside = {}
  lookaside_inverse = {}

  event_stream << Templates::RaidStart.result(binding)

  raiddoc.elements.each("raid/*") do |event|
    case event.name
    when "roster"
      old_actives = actives
      actives = []
      event.elements.each("player") do |p|
        name = p.attributes["name"]
        slot = p.attributes["using-slot-of"] || name
        if slot != name
          lookaside[name] = slot
          lookaside_inverse[slot] = name
        end
        actives << slot
      end
      event_stream << Templates::Roster.result(binding)

    when "initial-roll-in"
      listname = event.attributes["list"]
      list = lists[listname] = []
      event.elements.each("roll") do |m|
        list << m.attributes["player"]
      end
      event_stream << Templates::InitialRollin.result(binding)

    when "boss", "trash"
      changed_lists = []
      won_items = []
      de_items = []
      donated_items = []
      old_lists = {}

      event.elements.each("loot") do |l|
        l.elements.each("assigned") do |assignment|
          won_items << { :item => l, :assignment => assignment }

          listname = assignment.attributes["list"]
          list = lists[listname]
          unless changed_lists.include? listname
            changed_lists << listname
            old_lists[listname] = list.clone
          end

          player = assignment.attributes["player"]
          if lookaside[player]
            player = lookaside[player]
          end
          suicide(actives, list, player)
        end
        l.elements.each("disenchanted") do |de|
          de_items << { :item => l, :de => de }
        end
        l.elements.each("donated") do |donation|
          donated_items << { :item => l, :donation => donation }
        end
      end
      if event.name == "boss"
        event_stream << Templates::BossDown.result(binding)
      elsif event.name == "trash"
        event_stream << Templates::Drop.result(binding)
      end
    when "roll-in"
      send(rollin_function, event, lists, actives)
      list = lists[event.attributes["list"]]
      event_stream << Templates::Rollin.result(binding)
    when "raid-end"
      event_stream << Templates::RaidEnd.result(binding)
    when "comment"
      event_stream << Templates::Comment.result(binding)
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

      event_stream << Templates::RuleChange.result(binding)
    end
  end
  out = File.new(raidfile.sub('xml','html'), "w")
  out.puts Templates::Page.result(binding)
  out.close
end
