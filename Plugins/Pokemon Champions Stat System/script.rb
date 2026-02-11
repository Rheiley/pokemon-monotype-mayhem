module Settings
  #-----------------------------------------------------------------------------
  # Switch used to determine whether EV Stat Limit scales with the EV Limit
  #-----------------------------------------------------------------------------
  NO_STAT_SCALING   = 80
end

class Battle
    def pbGainEVsOne(idxParty, defeatedBattler)
    return
  end
end  

class Pokemon

  # Max total IVs
  IV_STAT_LIMIT = 31
  # Max total EVs
  EV_LIMIT      = 66
  # Max EVs that a single stat can have
  EV_STAT_LIMIT = 32
  
  def dynamic_ev
	  #===============================================================================
	  #Edit this to change when you get access to the stats
	  #Some examples;
	  #dynamic_ev = [self.level * 2, EV_LIMIT].min #Reaches max at Level 25
	  #dynamic_ev = [self.level / 2, EV_LIMIT].min #Reaches max at Level 100
	  return dynamic_ev = [self.level + 16, EV_LIMIT].min  #Reaches max at Level 50
	  end
  def dynamic_stat
	  #===============================================================================	
	  #Edit this to change how your stats scale #DO NOT GO BELOW 49!!!
	  #Some examples;
	  #dynamic_stat = [((self.dynamic_ev * 75) / 100).floor, EV_STAT_LIMIT].min 
	  #dynamic_stat = [((self.dynamic_ev * 60) / 100).floor, EV_STAT_LIMIT].min
	  return dynamic_stat = [((self.dynamic_ev * 49) / 100).floor, EV_STAT_LIMIT].min #With default settings you start with 10 at Level 5 and reach 32 at Level 50
	  end
	  #===============================================================================
	

  def calcHP(base, level, iv, ev)
    return 1 if base == 1   # For Shedinja
    iv = ev = 0 if Settings::DISABLE_IVS_AND_EVS
	return ((((base * 2) + iv + (ev * 2)) * level / 100).floor + level + 10)
  end
  
  def calcStat(base, level, iv, ev, nat)
    iv = ev = 0 if Settings::DISABLE_IVS_AND_EVS
    return (((((base * 2) + iv + (ev * 2)) * level / 100).floor + 5) * nat / 100).floor
  end
  
  # Creates a new Pokémon object.
  # @param species [Symbol, String, GameData::Species] Pokémon species
  # @param level [Integer] Pokémon level
  # @param owner [Owner, Player, NPCTrainer] Pokémon owner (the player by default)
  # @param withMoves [Boolean] whether the Pokémon should have moves
  # @param recheck_form [Boolean] whether to auto-check the form
  def initialize(species, level, owner = $player, withMoves = true, recheck_form = true)
    species_data = GameData::Species.get(species)
    @species          = species_data.species
    @form             = species_data.base_form
    @forced_form      = nil
    @time_form_set    = nil
    self.level        = level
    @steps_to_hatch   = 0
    heal_status
    @gender           = nil
    @shiny            = nil
    @ability_index    = nil
    @ability          = nil
    @nature           = nil
    @nature_for_stats = nil
    @item             = nil
    @mail             = nil
    @moves            = []
    reset_moves if withMoves
    @first_moves      = []
    @ribbons          = []
    @cool             = 0
    @beauty           = 0
    @cute             = 0
    @smart            = 0
    @tough            = 0
    @sheen            = 0
    @pokerus          = 0
    @name             = nil
    @happiness        = species_data.happiness
    @poke_ball        = :POKEBALL
    @markings         = []
    @iv               = {}
    @ivMaxed          = {}
    @ev               = {}
    GameData::Stat.each_main do |s|
      @iv[s.id]       = IV_STAT_LIMIT
      @ev[s.id]       = 0
    end
    case owner
    when Owner
      @owner = owner
    when Player, NPCTrainer
      @owner = Owner.new_from_trainer(owner)
    else
      @owner = Owner.new(0, "", 2, 2)
    end
    @obtain_method    = 0   # Met
    @obtain_method    = 4 if $game_switches && $game_switches[Settings::FATEFUL_ENCOUNTER_SWITCH]
    @obtain_map       = ($game_map) ? $game_map.map_id : 0
    @obtain_text      = nil
    @obtain_level     = level
    @hatched_map      = 0
    @timeReceived     = Time.now.to_i
    @timeEggHatched   = nil
    @fused            = nil
    @personalID       = rand(2**16) | (rand(2**16) << 16)
    @hp               = 1
    @totalhp          = 1
    calc_stats
    if @form == 0 && recheck_form
      f = MultipleForms.call("getFormOnCreation", self)
      if f
        self.form = f
        reset_moves if withMoves
      end
    end
  end
 end
 
MenuHandlers.add(:party_menu, :stats_editing, {
  "name"      => _INTL("Stats"),
  "order"     => 25,
  "condition" => proc { |screen, party, party_idx| next !party[party_idx].egg? },
  "effect"    => proc { |screen, party, party_idx|
    pkmn = party[party_idx]
		
    cmd2 = 0
    loop do
      totalev = 0
      evcommands = []
      ev_id = []
      # Build the list of stats and their current values
      GameData::Stat.each_main do |s|
        evcommands.push(s.name + " (#{pkmn.ev[s.id]})")
        ev_id.push(s.id)
        totalev += pkmn.ev[s.id]
      end
      
      # Display the menu with the total EV count
      cmd2 = screen.pbShowCommands(_INTL("Change which Stat?\nTotal: {1}/{2} ({3}%)",
                                         totalev, pkmn.dynamic_ev,
										 100 * totalev / pkmn.dynamic_ev), evcommands, cmd2)
      
      break if cmd2 < 0 # Exit menu
      
      if cmd2 < ev_id.length
        params = ChooseNumberParams.new
        upperLimit = 0
        # Calculate how many points are left to spend globally
        GameData::Stat.each_main { |s| upperLimit += pkmn.ev[s.id] if s.id != ev_id[cmd2] }
        upperLimit = pkmn.dynamic_ev - upperLimit
        # Respect the individual stat cap
		if $game_switches[Settings::NO_STAT_SCALING]
			upperLimit = [upperLimit, Pokemon::EV_STAT_LIMIT].min
		else
			upperLimit = [upperLimit, pkmn.dynamic_stat].min
        end
        thisValue = [pkmn.ev[ev_id[cmd2]], upperLimit].min
        params.setRange(0, upperLimit)
        params.setDefaultValue(thisValue)
        params.setCancelValue(thisValue)
        
        f = pbMessageChooseNumber(_INTL("Set the Stat for {1} (max. {2}).",
                                   GameData::Stat.get(ev_id[cmd2]).name, upperLimit), params) { screen.pbUpdate }
        
        if f != pkmn.ev[ev_id[cmd2]]
          pkmn.ev[ev_id[cmd2]] = f
          pkmn.calc_stats # Recalculate stats based on new EVs
          screen.pbRefreshSingle(party_idx) # Update the party screen UI
        end
      end
    end
  }
})

module GameData
  class Trainer
    # Creates a battle-ready version of a trainer's data.
    # @return [Array] all information about a trainer in a usable form
    def to_trainer
      # Determine trainer's name
      tr_name = self.name
      Settings::RIVAL_NAMES.each do |rival|
        next if rival[0] != @trainer_type || !$game_variables[rival[1]].is_a?(String)
        tr_name = $game_variables[rival[1]]
        break
      end
      # Create trainer object
      trainer = NPCTrainer.new(tr_name, @trainer_type, @version)
      trainer.id        = $player.make_foreign_ID
      trainer.items     = @items.clone
      trainer.lose_text = self.lose_text
      # Create each Pokémon owned by the trainer
      @pokemon.each do |pkmn_data|
        species = GameData::Species.get(pkmn_data[:species]).species
        pkmn = Pokemon.new(species, pkmn_data[:level], trainer, false)
        trainer.party.push(pkmn)
        # Set Pokémon's properties if defined
        if pkmn_data[:form]
          pkmn.forced_form = pkmn_data[:form] if MultipleForms.hasFunction?(species, "getForm")
          pkmn.form_simple = pkmn_data[:form]
        end
        pkmn.item = pkmn_data[:item]
        if pkmn_data[:moves] && pkmn_data[:moves].length > 0
          pkmn_data[:moves].each { |move| pkmn.learn_move(move) }
        else
          pkmn.reset_moves
        end
        pkmn.ability_index = pkmn_data[:ability_index] || 0
        pkmn.ability = pkmn_data[:ability]
        pkmn.gender = pkmn_data[:gender] || ((trainer.male?) ? 0 : 1)
        pkmn.shiny = (pkmn_data[:shininess]) ? true : false
        pkmn.super_shiny = (pkmn_data[:super_shininess]) ? true : false
        if pkmn_data[:nature]
          pkmn.nature = pkmn_data[:nature]
        else   # Make the nature random but consistent for the same species used by the same trainer type
          species_num = GameData::Species.keys.index(species) || 1
          tr_type_num = GameData::TrainerType.keys.index(@trainer_type) || 1
          idx = (species_num + tr_type_num) % GameData::Nature.count
          pkmn.nature = GameData::Nature.get(GameData::Nature.keys[idx]).id
        end
		GameData::Stat.each_main do |s|
		# Set IVs: Default to the Max IV Limit defined in your Pokemon class
		if pkmn_data[:iv]
			pkmn.iv[s.id] = Pokemon::IV_STAT_LIMIT
		end
		end
  
		if pkmn_data[:ev]
			pkmn.ev[s.id] = pkmn_data[:ev][s.id]
		else
			# Make the stats random but consistent for the same evo line used by the same trainer type
			base_species = GameData::Species.get(pkmn.species).get_baby_species
			species_num = GameData::Species.keys.index(base_species) || 1
			tr_type_num = GameData::TrainerType.keys.index(@trainer_type) || 1
			ev_seed = (species_num + 1) * ($player.id + tr_type_num)
			rng = Random.new(ev_seed)
			
			remaining_pool = pkmn.dynamic_ev
			max_per_stat = pkmn.dynamic_stat
			
			stat_ids = []
			GameData::Stat.each_main { |s| stat_ids << s.id }
			stat_ids = stat_ids.sort.shuffle(random: rng)
			
			while remaining_pool > 0
				available_stats = stat_ids.select { |s| pkmn.ev[s] < max_per_stat }
				
				break if available_stats.empty?
				
				target_stat = available_stats[rng.rand(available_stats.length)]
				room_in_stat = max_per_stat - pkmn.ev[target_stat]
				max_possible_add = [5, remaining_pool, room_in_stat].min
				chunk = rng.rand(1..max_possible_add)
			
			
				pkmn.ev[target_stat] += chunk
				remaining_pool -= chunk
			end
#DEBUG code to see Trainer's Pokémon EV's
echoln "----------------------------------------"
echoln "#{@trainer_type} #{trainer.name}'s #{pkmn.species} #{ev_seed}"
echoln "Final EV Spread: HP:#{pkmn.ev[:HP]} ATK:#{pkmn.ev[:ATTACK]} DEF:#{pkmn.ev[:DEFENSE]} SPATK:#{pkmn.ev[:SPECIAL_ATTACK]} SPDEF:#{pkmn.ev[:SPECIAL_DEFENSE]} SPEED:#{pkmn.ev[:SPEED]}"
echoln "========================================"
		end

        pkmn.happiness = pkmn_data[:happiness] if pkmn_data[:happiness]
        if !nil_or_empty?(pkmn_data[:real_name])
          pkmn.name = pbGetMessageFromHash(MessageTypes::POKEMON_NICKNAMES, pkmn_data[:real_name])
        end
        if pkmn_data[:shadowness]
          pkmn.makeShadow
          pkmn.shiny = false
        end
        pkmn.poke_ball = pkmn_data[:poke_ball] if pkmn_data[:poke_ball]
        pkmn.calc_stats
      end
      return trainer
    end
	end
	end