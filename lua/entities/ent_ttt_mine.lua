if SERVER then
	AddCSLuaFile()
end

ENT.Type = "anim"
ENT.PrintName = "Melon Mine"
ENT.Author = "Created by Phoenixf129 and reworked by BocciardoLight"
ENT.Purpose	= ""
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.Icon = "vgui/ttt/icon_melonmine.png"
ENT.Projectile = true

ENT.CanHavePrints = true

ENT.WarningSound = Sound("weapons/c4/c4_beep1.wav")

util.PrecacheSound("npc/scanner/combat_scan2.wav")

function ENT:SetupDataTables()
   self:NetworkVar( "String", 2, "OwnerTeam" )
end


local BoomPlayer

function ENT:Initialize()
	if SERVER then
		self.Entity:SetModel("models/props_junk/watermelon01.mdl") 
		self.Entity:SetColor(Color(150, 100, 0, 255))
		self.Entity:PhysicsInit(SOLID_VPHYSICS)
		self.Entity:DrawShadow( false )
		self.Entity:SetCollisionGroup( COLLISION_GROUP_WEAPON )
		self.Entity:SetTrigger( true )
		
		self.StartupDelay = CurTime()+3
		self.Entity:SetHealth(150)
		self.Entity:WeldToGround(true)
		self.fingerprints = {}
		if not self:GetDmg() then self:SetDmg(200) end
	end
	
	if CLIENT then
		self.DrawText = false
	    self.Text = ""
		local rand = math.random(1,3)
		if rand == 1 then self.Text = "O_O"
		elseif rand == 2 then self.Text = "O.o"
		else self.Text = "-.-" end
		timer.Simple(3, function()
			if IsValid( self.Entity ) then
				self.Entity.DrawText = true
			end
		end)
	end
end

if CLIENT then
    surface.CreateFont("TrebuchetMelon", { font = "Trebuchet24", size = 60 })
end
	
function ENT:Draw()
	self.Entity:DrawModel()
	local FixAngles = self.Entity:GetAngles()
	local FixRotation = Vector(0, 270, 0)

	FixAngles:RotateAroundAxis(FixAngles:Right(), 	FixRotation.x)
	FixAngles:RotateAroundAxis(FixAngles:Up(), 		FixRotation.y)
	FixAngles:RotateAroundAxis(FixAngles:Forward(), FixRotation.z)
	local TargetPos = self.Entity:GetPos() + (self.Entity:GetUp() * 9)
	local _,_,_,a = self:GetColor()
	
	if self.DrawText then
		cam.Start3D2D(TargetPos, FixAngles, 0.15)
		draw.SimpleText(self.Text, "TrebuchetMelon", TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, Color(255,0,0,a),1,1)
		cam.End3D2D() 
	end
end

ENT.StartupDelay = nil

AccessorFunc( ENT, "dmg", "Dmg", FORCE_NUMBER )

function ENT:WeldToGround(state)
   --if self.IsOnWall then return end

   if state then
      -- getgroundentity does not work for non-players
      -- so sweep ent downward to find what we're lying on
      local ignore = player.GetAll()
      table.insert(ignore, self.Entity)

      local tr = util.TraceEntity({start=self:GetPos(), endpos=self:GetPos() - Vector(0,0,16), filter=ignore, mask=MASK_SOLID}, self.Entity)

      if tr.Hit and (IsValid(tr.Entity) or tr.HitWorld) then
         local phys = self:GetPhysicsObject()
         if IsValid(phys) then
            if tr.HitWorld then
               phys:EnableMotion(false)
            else
               self.OrigMass = phys:GetMass()
               phys:SetMass(150)
            end
         end

         -- only weld to objects we cannot pick up
         local entphys = tr.Entity:GetPhysicsObject()
         if IsValid(entphys) and entphys:GetMass() > CARRY_WEIGHT_LIMIT then
            constraint.Weld(self, tr.Entity, 0, 0, 0, true)
         end
      end
   else
      constraint.RemoveConstraints(self.Entity, "Weld")
      local phys = self:GetPhysicsObject()
      if IsValid(phys) then
         phys:EnableMotion(true)
         phys:SetMass(self.OrigMass or 10)
      end
   end
end

if SERVER then
	function ENT:Think()
		if self.StartupDelay and self.StartupDelay < CurTime() then
			local e = ents.FindInSphere( self.Entity:GetPos(), 150 )
			for a, pl in pairs(e) do
				-- Doesn't detonate for traitors
				if (IsValid(pl) and pl:IsPlayer()) then
					if pl:GetTeam() == self:GetOwnerTeam() then return end
					if pl.IsGhost and pl:IsGhost() then return end
					local rags = ents.FindByClass("prop_ragdoll")
					table.insert(rags, self.Entity)
					local trace = {}
					trace.start = self.Entity:GetPos()
					trace.endpos = pl:GetPos()+Vector(0,0,60)
					trace.filter = rags
					local tr = util.TraceLine( trace )
					-- Checks if there's a clear view of the player
					if IsValid(tr.Entity) and tr.Entity == pl then
						BoomPlayer = pl
						timer.Create("beep", 0.1, 8, function()
							self.Entity:EmitSound("weapons/c4/c4_beep1.wav")
						end)
						timer.Simple(1, function() self:Explode() end)
						function self.Think() end
					end
				elseif pl:GetClass() == "ttt_chicken" then
					local rags = ents.FindByClass("prop_ragdoll")
					table.insert(rags, self.Entity)
					local trace = {}
					trace.start = self.Entity:GetPos()
					trace.endpos = pl:GetPos()+Vector(0,0,60)
					trace.filter = rags
					local tr = util.TraceLine( trace )
					if IsValid(tr.Entity) and tr.Entity == pl then
						BoomPlayer = pl
						timer.Create("beep", 0.1, 8, function()
							self.Entity:EmitSound("weapons/c4/c4_beep1.wav")
						end)
						timer.Simple(1, function() self:Explode() end)
						function self.Think() end
					end
				end
			end
		end
	end
end

if SERVER then
	function ENT:Explode()
		  self.Entity:SetNoDraw(true)
		  self.Entity:SetSolid(SOLID_NONE)
			local pos = self.Entity:GetPos()
			if self.Entity:GetPos().z < (BoomPlayer:GetPos().z + 50)  then
				pos.z = pos.z + 30
			end
			
		  local dmgowner = self:GetOwner()
		  dmgowner = IsValid(dmgowner) and dmgowner or self.Entity

		  local r_inner = 200
		  local r_outer = 240

		  -- damage through walls
		  --self:SphereDamage(dmgowner, pos, r_inner)

		  -- explosion damage
		  util.BlastDamage(self, dmgowner, pos, r_outer, self:GetDmg())

		  sound.Play( "explode_4", self.Entity:GetPos(), 130, 100 )
		  
		  local effect = EffectData()
		  effect:SetStart(pos)
		  effect:SetOrigin(pos)
		  -- these don't have much effect with the default Explosion
		  effect:SetScale(r_outer)
		  effect:SetRadius(r_outer)
		  effect:SetMagnitude(self:GetDmg())

		  effect:SetOrigin(pos)
		  util.Effect("Explosion", effect, true, true)
		  util.Effect("HelicopterMegaBomb", effect, true, true)
		  
		  -- extra push
		  local phexp = ents.Create("env_physexplosion")
		  phexp:SetPos(pos)
		  phexp:SetKeyValue("magnitude", self:GetDmg())
		  phexp:SetKeyValue("radius", r_outer)
		  phexp:SetKeyValue("spawnflags", "19")
		  phexp:Spawn()
		  phexp:Fire("Explode", "", 0)
		  
		  self:Remove()
	end
	
	local zapsound = Sound("npc/assassin/ball_zap1.wav")
	function ENT:OnTakeDamage( dmginfo )
	   if dmginfo:GetAttacker() == self:GetOwner() then return end

	   self:TakePhysicsDamage(dmginfo)

	   self:SetHealth(self:Health() - dmginfo:GetDamage())
	   if self:Health() < 0 then
		  self:Remove()

		  local effect = EffectData()
		  effect:SetOrigin(self:GetPos())
		  util.Effect("cball_explode", effect)
		  sound.Play(zapsound, self:GetPos())

		  if IsValid(self:GetOwner()) then
			 TraitorMsg(self:GetOwner(), "YOUR MINE HAS BEEN DESTROYED!")
		  end
	   end
	end
end

function ENT:SphereDamage(dmgowner, center, radius)
   -- It seems intuitive to use FindInSphere here, but that will find all ents
   -- in the radius, whereas there exist only ~16 players. Hence it is more
   -- efficient to cycle through all those players and do a Lua-side distance
   -- check.

   local r = radius ^ 2 -- square so we can compare with dotproduct directly


   -- pre-declare to avoid realloc
   local d = 0.0
   local diff = nil
   local dmg = 0
   for _, ent in pairs(player.GetAll()) do
      if IsValid(ent) and ent:Team() == TEAM_TERROR then

         -- dot of the difference with itself is distance squared
         diff = center - ent:GetPos()
         d = diff:DotProduct(diff)

         if d < r then
            -- deadly up to a certain range, then a quick falloff within 100 units
            d = math.max(0, math.sqrt(d) - 490)
            dmg = -0.01 * (d^2) + 125

            local dmginfo = DamageInfo()
            dmginfo:SetDamage(dmg)
            dmginfo:SetAttacker(dmgowner)
            dmginfo:SetInflictor(self.Entity)
            dmginfo:SetDamageType(DMG_BLAST)
            dmginfo:SetDamageForce(center - ent:GetPos())
            dmginfo:SetDamagePosition(ent:GetPos())

            ent:TakeDamageInfo(dmginfo)
         end
      end
   end
end

function ENT:WallPlant(hitpos, forward)
	if (hitpos) then self.Entity:SetPos( hitpos ) end
    self.Entity:SetAngles( forward:Angle() + Angle( -90, 0, 180 ) )
	
end