--start of file

--require egps


--local x=0
--local y=0
--local z=0
--local storedX=0
--local storedY=0
--local storedZ=0
--fuel chest is accessible at 0,0,0, with direction at 3. (west side)
--items chest is accessible at 0,0,0 with direction at 2. (south side)
local layerX=0
local layerZ=0

local chest_item="enderstorage:ender_storage"

local protectedItems={chest_item}
local keepOneStack={"minecraft:coal","minecraft:charcoal"}
local allowedFuel={"minecraft:coal","minecraft:charcoal","minecraft:planks"}

local item_chestSlot=16
local fuel_chestSlot=15
local fuel_slot=14
local preferred_fuel_percentage=0.8
local minimum_fuel_percentage=0.2

local saved_level=0
local saved_row=0
local saved_home=nil --SET WHEN HOME IS SET



local function askSize() --will ask the player for the size of the quarry

end

local function contains(table,item)
    for k,v in pairs(table) do
        if table[k]==item then
            return true
        end
    end
    return false
end

local function dig() --will try to dig. looking to make this more complicated, with checks 'n shit, but for now this is fine.
    if turtle.dig() then
        return true
    else
        return false
    end
end

local function moveForwardBreak()
    while turtle.detect() do
        turtle.dig()
    end
    egps.forward()
end

local function begin() --should only ever be called once. this resets everything.
    egps.setLocationFromGPS()
    --detect chests

    while not turtle.inspect().name=="minecraft:chest" do
        sleep(1)
    end
    while not turtle.inspect().name=="minecraft:chest" do
        sleep(1)
    end
end

local function mineLayer(xSize,zSize)--starting spot is the first block to break. i'm not moving forward or anything.
    local startingX,startingY,startingZ,startingD=egps.getLocation()
    local row=1
    local even=nil
    for i=1,xSize do
        --print("beginning of xSize loop. i: ",i)
        if (i%2==0) then
            even=true
        else
            even=false
        end
        for j=1,zSize do
            --print("beginning of zSize loop. j: ",j)
            turtle.digDown()
            turtle.digUp()
            if turtle.detectDown() then
                while turtle.detectDown() do --repeatedly try to break down until i can't break down. this won't use power, so if a player finds me there's little consequence to be breaking
                    turtle.digDown()
                    print("trying to make a block be nonexistant below me")
                end
            end
            if j==zSize then
                --print("j==zSize")
            else
                moveForwardBreak()
                --print("moveForwardBreak")
            end --if i'm at the end, don't move
        end
        if i==xSize then --if i'm at the end, don't try 'n turn around. just go back home.
            egps.moveTo(startingX,startingY,startingZ,startingD,true,1)
        else
          --turn around! do a 180; turn, move, turn again. odd numbers of x turn left, even numbers turn right.
          if even then
            egps.turnLeft()
            moveForwardBreak()
            egps.turnLeft()
          else
            egps.turnRight()
            moveForwardBreak()
            egps.turnRight()
          end
        end
    end
end

--[[local function resupply(itemName,count,slot)
    --uses the supply chest (slot 15) to grab a specific item in a specific count, and put it in a specific slot
    --check; if slot has an item in it, do this
        --if the item isn't equal to the item i'm looking for, return false
        --else if the item is what i'm looking for, reduce the count by the amount of items already in the slot

end]] --WILL NOT WORK UNLESS I FIND A WAY TO GRAB A SPECIFIC ITEM. FUCK.

local function enderUnload(protected,oneStack,temp_chestSlot)
    local itemList=nil
    local oneStackCache={}
    local orig_slot=turtle.getSelectedSlot() --store the slot i had selected before i started this function
    if not type(protectedItems) == "table" then
        protectedItems=nil
    end
    --select 16. if no ender chest is present, return false
    turtle.select(temp_chestSlot)
    itemList=turtle.getItemDetail()
    if not itemList["name"]==chest_item then
        return "error! i dont have an ender chest wtf wtf wtf"
    end
    turtle.dig()

    while not turtle.place() do
        turtle.dig()
    end

    local itemList={0,1}

    for slot=1, 16 do
        turtle.select(slot)
        if not(slot == temp_chestSlot) then
            itemList=turtle.getItemDetail(slot)
            if not(itemList==nil) then
                if not(contains(protected,itemList["name"]) or contains(oneStack,itemList["name"])) then
                    turtle.drop()
                end
                if contains(oneStack,itemList["name"]) then
                    if contains(oneStackCache,itemList["name"]) then
                        turtle.drop()
                    else
                        table.insert(oneStackCache, itemList["name"])
                    end
                end
            end
        end
    end

    turtle.select(temp_chestSlot)
    turtle.drop() --drop items if there's anything in there (it shouldnt be there)
    turtle.dig()
    turtle.select(orig_slot) --go back to the original slot i had selected before i started this function
end

local function refuel(refuelPercentage,fuelTypes,fuelSlot,chestSlot)
    if turtle.getFuelLevel()/turtle.getFuelLimit()>refuelPercentage then return true end
    local orig_slot=turtle.getSelectedSlot()
    local temp_table={}
    --will refuel until fuel level is above refuelPercentage
    for i=1,16 do
        turtle.select(i)
        if turtle.getItemDetail(i) then
            if contains(fuelTypes,turtle.getItemDetail(i)["name"]) then
                while (turtle.getFuelLevel()/turtle.getFuelLimit())<refuelPercentage do
                    if not turtle.refuel() then
                        break --try to refuel. if the result is false (didn't refuel for some reason) let's break and try another slot
                    end
                end
                if (turtle.getFuelLevel()/turtle.getFuelLimit())>refuelPercentage then
                    turtle.select(orig_slot)
                    return true --idunno if i broke or ended. if i broke, this'll be too low. if i didn't break, this should be good!
                end
            end
        end
    end
    --if slot 14 is empty, select slot 15 and check that ["name"]==chest_item, then place it and select 14, then take out a single stack of coal
    --then select 15 and break ender chest, then select 14 and refuel'
    turtle.select(fuelSlot)
    if contains(fuelTypes,turtle.getItemDetail(fuelSlot)["name"]) then
        while (turtle.getFuelLevel()/turtle.getFuelLimit())<refuelPercentage do
            if turtle.refuel()[1]==false then
                break --try to refuel. if the result is false (didn't refuel for some reason) let's break and try a last resort.
            end
        end
    else
        enderUnload(protectedItems,item_chestSlot) --this means there's clutter. if there's clutter, there's bullshit, so i'm just gonna unload everything for a bit brb
    end
    if (turtle.getFuelLevel()/turtle.getFuelLimit())>refuelPercentage then
        turtle.select(orig_slot)
        return true --again, idunno if i broke or ended. if i broke, this'll be too low. if i didn't break, this should be good!
    end
    turtle.select(chestSlot) --if after all that i'm still in this function, let's continue; i haven't finished refuelling
    if turtle.getItemDetail(chestSlot)["name"]==chest_item then --enter a series of loops built around grabbing fuel from the chest and using the fuel from the chest
        turtle.place()--place the chest!
        turtle.select(fuelSlot)
        while (turtle.getFuelLevel()/turtle.getFuelLimit())<refuelPercentage do --while i'm not fueled enough, do this
            if not turtle.suck(64) then
                print("error during refuelling: unable to grab items from chest!")
                turtle.select(chestSlot)
                turtle.dig()
                turtle.select(orig_slot)
                return false --just finish up because i wasn't able to grab items from the chest. oops!
            end --should be fine, but in the name of being careful
            while ((turtle.getFuelLevel()/turtle.getFuelLimit())<refuelPercentage) and turtle.getItemCount(fuelSlot)>0 do
                if not turtle.refuel() then
                    print("error during refuelling: unable to refuel!")
                    print("held item: ",turtle.getItemDetail(fuelSlot)["name"])
                    turtle.select(chestSlot)
                    turtle.dig()
                    turtle.select(orig_slot)
                    return false --just finish up because i wasn't able to refuel [for some reason]. oops!
                end
            end
            if turtle.getItemCount(fuelSlot)>0 then
                break --if i still have items in that slot, the only way i could've broken that while is if i finished refuelling. i'm done!
            end--if i haven't broken by now, then let's go for another loop; let's grab more items from the chest in front of us and try to refuel again
        end
        turtle.select(chestSlot)--break the chest. don't need that anymore!
        turtle.dig()
        turtle.select(orig_slot)
        if (turtle.getFuelLevel()/turtle.getFuelLimit())>refuelPercentage then
            return true
        else
            return false --shouldn't happen, but i'm not about to incorrectly report true when it should be false
        end
    else
        turtle.select(orig_slot)
        return false --i've failed you, master. (damn. i tried so many things! this shouldn't happen, but it's theoretically possible
        --if coal's REALLY SCARCE and something broke my chest during a previous attempt to refuel)
    end

end

local function mineInventory()
    --grab all of it's items until i'm full, then turn around and execute enderchest. it WILL repeatedly break and place the enderchest, but that's okay in the name of efficient coding rather than efficient execution
    --then turn back and continue emptying. repeat until inventory is empty, then mine the inventory
    print("MINEINVENTORY CALLED")
    print(turtle.inspectUp())
    print(turtle.inspectDown())
    print(turtle.inspect())
end

local function checks()
    --check fuel, inventory, etc.
    --fuel is simple; check fuel. if fuel's under minimum percentage, go to fuel slot and grab some!
    if turtle.getFuelLevel()<minimum_fuel_percentage then
        refuel()
    end
    --check if there's an inventory wherever i'd mine (up, down, and front). if so, execute mineInventory()
    if (turtle.inspectDown()[2]["name"]=="minecraft:chest" or turtle.inspectup()[2]["name"]=="minecraft:chest" or turtle.inspect()[2]["name"]=="minecraft:chest") then
        mineInventory()
    end
    --items are simple, too. check slots 12 and 13; if they're empty, we're good! continue. slots 14, 15, and 16 are reserved for fuel, fuelchest, and emptychest respectively.
    if turtle.getItemDetails(12) and turtle.getItemDetails(13) then
        enderUnload(protectedItems,keepOneStack,item_chestSlot)
    end
end

local function mineLoop(xSize,zSize,downSize)
    if downSize==nil then
        downSize=8192 --assume we're literally in space if no downSize is specified; just keep going down. will be dealt with if bedrock is encountered
    end
end
--mineLayer(10,10)

local function begin()
    refuel(preferred_fuel_percentage,allowedFuel,fuel_slot,fuel_chestSlot)
    egps.startGPS()
    sleep(1)
    egps.setLocationFromGPS()
    local home=egps.getLocation()
    print("HOME:",home)
end

local xSize,zSize=10,10 --TEMPORARY
minimum_fuel_percentage=0.01*math.floor(400*((256+xSize+zSize)/turtle.getFuelLimit())) --minimum blocks / fuel limit
print(minimum_fuel_percentage)

os.loadAPI("egps.lua")
for i=0,3 do
     turtle.dig()
     turtle.turnLeft()
end

begin()






enderUnload(protectedItems,keepOneStack,item_chestSlot)
