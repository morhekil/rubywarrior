module PlayerSight
  def enemy_behind?(warrior)
    enemy_sighted? warrior.look(:backward)
  end

  def wall_ahead?(warrior)
    wall_sighted? warrior.look
  end

  def stairs_ahead?(warrior)
    stairs_sighted? warrior.look
  end

  def enemy_ahead?(warrior)
    enemy_sighted? warrior.look
  end

  def captive_behind?(warrior)
    captive_sighted? warrior.look(:backward)
  end

  def stairs_sighted?(sight)
    next_up = sight.reject { |s| s.empty? && !s.stairs? }.first
    next_up && next_up.stairs?
  end

  def wall_sighted?(sight)
    next_up = first_unit sight
    next_up && next_up.wall?
  end

  def captive_sighted?(sight)
    next_up = first_unit sight
    next_up && next_up.captive?
  end

  def first_unit(sight)
    sight.reject(&:empty?).first
  end

  def enemy_sighted?(sight)
    next_up = first_unit sight
    next_up && next_up.enemy? && next_up.unit.character
  end

  def archer_sighted?(sight)
    enemy_sighted?(sight) == 'a'
  end

end

module PlayerBrain
  MAX_HEALTH = 20
  REST_HEALTH_LIMIT = 10
  FIGHT_BACKOUT_LIMIT = 10

  def maybe_pivot?(warrior)
    enemy_behind?(warrior) || captive_behind?(warrior) ||
      (wall_ahead?(warrior) && !stairs_ahead?(warrior))
  end

  def maybe_enemy_behind?(warrior)
    ahead = enemy_ahead? warrior
    no_attacker_ahead = !ahead || (warrior.feel.empty? && ahead != 'a')
    no_attacker_ahead && dying?(warrior)
  end

  def need_to_run?(warrior)
    look_back = warrior.look(:backward)
    warrior.health <= FIGHT_BACKOUT_LIMIT && dying?(warrior) &&
      !enemy_sighted?(look_back[0..1]) && !archer_sighted?(look_back)
  end

  def maybe_rest?(warrior)
    resting = @prev_action == :rest! && warrior.health < MAX_HEALTH

    !dying?(warrior) && (resting || warrior.health <= REST_HEALTH_LIMIT)
  end

  def dying?(warrior)
    warrior.health < @prev_health.to_i
  end
end

class Player
  include PlayerSight
  include PlayerBrain

  def play_turn(warrior)
    @direction ||= :forward

    action = what_to_do_next warrior

    @prev_action = action
    @prev_health = warrior.health
    action = [action] unless action.is_a? Array
    warrior.send(*action)
  end

  def what_to_do_next(warrior)
    cell = warrior.feel @direction
    case
    when maybe_enemy_behind?(warrior) then :pivot!
    when need_to_run?(warrior)        then [:walk!, opposite_direction]
    when enemy_ahead?(warrior)        then [:shoot!, @direction]
    when maybe_pivot?(warrior)        then :pivot!
    when cell.empty?                  then rest_or_walk! warrior
    else act_on_thing cell, warrior
    end
  end

  def act_on_thing(cell, warrior)
    if cell.wall?
      :pivot!
    elsif cell.captive?
      [:rescue!, @direction]
    else
      [:attack!, @direction]
    end
  end

  def rest_or_walk!(warrior)
    maybe_rest?(warrior) ? :rest! : [:walk!, @direction]
  end

  def turn_around
    @direction = opposite_direction
  end

  def opposite_direction
    (%i(backward forward) - [@direction]).first
  end

end
