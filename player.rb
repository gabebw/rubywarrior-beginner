require './map'
class Player
  ATTACK_POWER = 5 # Damage warrior deals per turn
  MAX_HEALTH = 20  # Maximum health of warrior
  # We want to have at least this % health
  MINIMUM_PERCENT_HEALTH = 50

  def set_variables!(warrior)
    @previous_health = current_health
    @previous_direction = nil
    # If recuperating is true, then rest until at max health before continuing
    @recuperating = false
    @map = Map.new(self, warrior)

    @already_set_variables = true
  end

  attr_accessor :direction
  attr_reader :previous_direction

  def play_turn(warrior)
    @warrior = warrior # yes, you have to set this each time
    set_variables!(warrior) unless @already_set_variables
    @map.update!(warrior)

    perform_action!(warrior)

    # Set variables for next turn
    previous_health = current_health
    @previous_direction = warrior.action[1] # may be nil!
    @map.previous_location = current_location
  end

  # Performs a bang-action, e.g. walk!
  def perform_action!(warrior)
    # available methods for a Space (returned by warrior.feel)
    # TESTERS
    #   stairs?
    #   empty?
    #   enemy?
    #   captive?
    #   wall?
    #   ticking? (OMINOUS!)
    # TYPE GETTERS
    #   unit (e.g. "Thick Sludge", may be nil)
    #   location - An [X-coord, Y-coord] pair
    #     - A coordinate may be < 0, e.g. if you're at [0, 0],
    #       then warrior.feel(:backward).location = [-1, 0]
    #   character (e.g. "S" for a thick sludge, may be nil)
    # Note that the stairs space is empty (unless a unit is on it), i.e.
    # space.empty? returns true for the stairs space, so explicitly check
    # for stairs.

    # We can get away with only feeling in one direction, for now.
    space = warrior.feel(direction)

    # The stairs space may not be empty, e.g. if an enemy or captive is on
    # it
    if space.stairs? and space.empty?
      warrior.walk!(direction)
    elsif current_location == [1, 0] and warrior.feel(:backward).empty?
      # Nothing more to do here
      @direction = :forward
      warrior.walk!(direction)
    elsif @map.just_killed_an_enemy
      if @map.is_safe_location?(current_location)
        puts "current location is safe"
        if warrior.health < MAX_HEALTH
          warrior.rest!
        else
          # OK, forget about that enemy we just killed.
          # WE'RE AT MAX HEALTH AND READY TO ROCK!
          @map.just_killed_an_enemy = false
          @direction = @map.towards_current_enemy
          warrior.walk!(direction)
        end
      else
        puts "current location is NOT safe"
        reverse_direction!
        @direction = @map.towards_safe_space
        warrior.walk!(direction)
      end
    elsif space.captive?
      warrior.rescue!(direction)
    elsif space.enemy?
      @map.register_enemy_at!(space.location, space.character)
      @map.decrement_enemys_health_at(space.location)
      warrior.attack!(direction)
    elsif space.empty?
      warrior.walk!(direction)
    elsif space.wall?
      # Hit a wall, switch direction and retry
      reverse_direction!
      perform_action!(warrior)
    else
      puts "!!! Weird space: #{space.inspect}"
      warrior.walk!(direction)
    end
  end

  ####################
  #  STATE CHANGERS  #
  ####################

  def reverse_direction!
    @direction = @map.opposite_direction_of(direction)
  end

  #############
  #  TESTERS  #
  #############

  # Is this space safe to rest in?
  # Note that it doesn't take into account whether the warrior is taking
  # damage.
  def in_safe_space?
    not taking_damage? and not next_to_enemy?
  end

  # Should the warrior rest? Note that this doesn't take into account
  # whether it's safe for the warrior to rest, it just recommends that he
  # should.
  def should_rest?
    # No need to rest when we're about to clear the level
    return false if @warrior.feel(direction).stairs?
    return false if @warrior.health == MAX_HEALTH

    if @recuperating
      # Stop recuperating if at max health
      @recuperating = @warrior.health < MAX_HEALTH
      @recuperating
    else
      low_on_health? or not healthy_enough_to_beat_enemy_at?(@map.location_of_closest_enemy)
    end
  end

  # Is an enemy in an adjacent space?
  def next_to_enemy?
    Map::DIRECTIONS.any? { |dir| @warrior.feel(dir).enemy? }
  end

  def taking_damage?
    current_health < @previous_health
  end

  def taking_damage_from_afar?
    taking_damage? and not next_to_enemy?
  end

  # Did we just start taking damage this turn?
  def just_started_taking_damage?
    taking_damage? and @map.is_safe_location?(@map.previous_location)
  end

  def low_on_health?
    percent_health = (current_health.to_f / MAX_HEALTH) * 100
    percent_health < MINIMUM_PERCENT_HEALTH
  end

  # Do we have enough health to engage in battle?
  def healthy_enough_to_beat_enemy_at?(enemy_location)
    turns = turns_required_to_beat_enemy_at(enemy_location)
    enemy_info = @map.get_info_about_enemy_at(enemy_location)
    # Archers attack from a distance of 2 squares, but if we're right next
    # to them then we need fewer turns
    turns += [2, @map.get_distance_away(enemy_info[:location])].min if enemy_info[:character] == :a
    predicted_damage_taken = turns * enemy_info[:damage]
    predicted_damage_taken < current_health
  end

  ###############
  #  ACCESSORS  #
  ###############

  def current_health
    @warrior.health
  end

  # Get direction warrior is walking in. Defaults to :backward.
  def direction
    @direction ||= :backward
  end

  #############
  #  UTILITY  #
  #############

  # Pass in an enemy location to determine how many turns it
  # will take to kill it once you're next to it.
  def turns_required_to_beat_enemy_at(enemy_location)
    info = @map.get_info_about_enemy_at(enemy_location)
    turns = (info[:health].to_f / ATTACK_POWER).ceil
    turns
  end

  def current_location
    backward = @warrior.feel(:backward).location
    x_coord = backward[0] + 1
    y_coord = backward[1]
    [x_coord, y_coord]
  end
end
