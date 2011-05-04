module Main where

import Types
import Locations
import Directions
import Objects
import Tools
import Control.Monad.State (get, gets, StateT(..), evalStateT, 
                            put, MonadState(..), liftIO)



parseCommand :: String -> (Maybe Command, String)
parseCommand [] = (Nothing, [])
parseCommand str = case reads capStrings of
					[(x,"")] -> (Just x, [])
					_ -> case head capStrings of
						'Q' -> (Just Quit, "Be seen you...")
						'I' -> (Just Inventory, [])
						'P' -> case reads wordsAfterCommand of
							[(y, "")] -> (Just (Pickup y), [])
							_ -> (Nothing, "Pickup what?")
						_ -> (Nothing, "Can't understand a command.")
						where wordsAfterCommand = unwords . tail . words $ capStrings
	where capStrings = capitalize $ str

newGameState :: Locations -> Room -> LongDescribedRooms -> InventoryObjects -> GameState
newGameState newLocations newRoom newLongDescribedRooms newInventory = GameState {
	gsLocations = newLocations,
	gsCurrentRoom = newRoom,
	gsRoomLongDescribed = newLongDescribedRooms,
	gsInvObjects = newInventory}

canWalk :: GameState -> Direction -> Maybe Room
canWalk = roomOnDirection . locPaths . location . gsCurrentRoom

tryWalk dir curGS = do
	case canWalk curGS dir of
		Just room -> do
			put (newGameState (gsLocations curGS) room newLongDescribedRooms (gsInvObjects curGS))
			ioOutMsgGS $ (describeLocation roomAlreadyLongDescribed room (locationObjects (gsLocations curGS) room))
			return ContinueGame
				where
					roomsDescribedEarlier = gsRoomLongDescribed curGS
					roomAlreadyLongDescribed = isRoomLongDescribed roomsDescribedEarlier room
					newLongDescribedRooms = if roomAlreadyLongDescribed then roomsDescribedEarlier else room : roomsDescribedEarlier
		Nothing -> return ContinueGame

		
whatObjectExactly :: Objects -> Maybe Object
whatObjectExactly [] = Nothing
whatObjectExactly (x:[]) = Just x
whatObjectExactly xs = do
	x <- return (ioOutMsgGS ( describeObjects "What object of these variants: " xs ))
	undefined
		
tryPickup itemNme curGS = do
	case whatObjectExactly (objectListFromObjectsByItemName itemNme curLocObjects) of
		Nothing -> ioOutMsgGS "Ok." >> return ContinueGame
		Just obj ->	case tryRiseObject obj of
			(Nothing, str) -> (ioOutMsgGS $ str) >> return ContinueGame
			(Just x, str) -> do
				(ioOutMsgGS $ str)
				put (newGameState (locationsWithoutObject curLocStates curRoom obj) curRoom curRoomLongDescribed (obj : curInventory))
				return ContinueGame
	where
		curLocStates = gsLocations curGS
		curRoom = gsCurrentRoom curGS
		curInventory = gsInvObjects curGS
		curRoomLongDescribed = gsRoomLongDescribed curGS
		curLocObjects = locObjects' curRoom curLocStates
		locObjects' room locs = locObjects . head $ (filter (\y -> room == locRoom y) locs)

run :: GS Result
run = do
	curGS <- get
	strCmd <- liftIO inputStrCommand
	let parsedCmdWithContext = parseCommand strCmd
	let currentRoom = gsCurrentRoom $ curGS
	let roomObjects = locationObjects (gsLocations curGS) currentRoom
	let inventory = gsInvObjects curGS
	case parsedCmdWithContext of
		(Nothing, str) -> (ioOutMsgGS $ str) >> run
		(parsedCmd, str) -> case parsedCmd of
			Just Quit -> ioOutMsgGS str >> return QuitGame
			Just Look -> ioOutMsgGS (lookAround currentRoom roomObjects) >> run
			Just Inventory -> (ioOutMsgGS . showInventory $ inventory) >> run
			Just (Investigate itemNme) ->
				if canSeeObj itemNme
				then invObj >> run
				else (noVisObjMsg itemNme) >> run
					where invObj = ioOutMsgGS  (investigateObject itemNme (roomObjects ++ inventory))
			Just (Go dir) -> (tryWalk dir curGS) >> run
			Just (Walk dir) -> (tryWalk dir curGS) >> run
			Just (Pickup itemNme) -> if canSeeObj itemNme then (tryPickup itemNme curGS) >> run else (noVisObjMsg itemNme) >> run
			Nothing -> (ioOutMsgGS . show $ parsedCmd) >> run
			where
				canSeeObj = canSeeObject (roomObjects ++ inventory)
				noVisObjMsg = ioOutMsgGS . notVisibleObjectError
				

main :: IO ()
main = do
	putStrLn $ lookAround startRoom startRoomObjects
	x <- evalStateT (runGameState run) initWorld
	putStrLn ""
		where
			startRoom = gsCurrentRoom $ initWorld
			startRoomObjects = locObjects . location $ startRoom