module Main where

import Types
import Objects
import Tools
import GameState
import Locations
import Control.Monad.State (get, gets, StateT(..), evalStateT, 
                            put, MonadState(..), liftIO)
import Char(isDigit, digitToInt)


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

parseObject :: String -> Objects -> Maybe Object
parseObject _ [] = Nothing
parseObject str objects = case read str of
						[(x, "")] -> case isDigit x of
							True -> Just ( objects!!((digitToInt x)-1) )
							False -> Nothing
	
{-


tryWalk :: Direction -> GameState -> GS GameResult
tryWalk dir curGS = case canWalk curGS dir of
		Just room -> do
			put (newGameState (gsLocations curGS) room newLongDescribedRooms (gsInvObjects curGS))
			ioOutMsgGS $ (describeLocation roomAlreadyLongDescribed room (locationObjects (gsLocations curGS) room))
			return ContinueGame
				where
					roomsDescribedEarlier = gsRoomLongDescribed curGS
					roomAlreadyLongDescribed = isRoomLongDescribed roomsDescribedEarlier room
					newLongDescribedRooms = if roomAlreadyLongDescribed then roomsDescribedEarlier else room : roomsDescribedEarlier
		Nothing -> return ContinueGame


run' :: GS GameActionCommand
run' = do
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
			Just Look -> ioOutMsgGS () >> run
			Just Inventory -> (ioOutMsgGS . showInventory $ inventory) >> run
			Just (Investigate itemNme) ->
				if canSeeObj itemNme
				then invObj >> run
				else (noVisObjMsg itemNme) >> run
					where invObj = ioOutMsgGS  (investigateObject itemNme (roomObjects ++ inventory))
			Just (Go dir) -> (tryWalk dir curGS) >> run
			Just (Walk dir) -> (tryWalk dir curGS) >> run
		--	Just (Pickup itemNme) -> if canSeeObj itemNme then (tryPickup' itemNme roomObjects curGS) >> run else (noVisObjMsg itemNme) >> run
			Nothing -> (ioOutMsgGS . show $ parsedCmd) >> run
			where
				canSeeObj = canSeeObject (roomObjects ++ inventory)
				noVisObjMsg = ioOutMsgGS . notVisibleObjectError
				-}


				
run' :: String -> GS GameActionResult
run' msg = do
		curGS <- get
		let currentRoom = gsCurrentRoom curGS
		let roomObjects = locationObjects (gsLocations curGS) currentRoom
		let inventory = gsInvObjects curGS
		case parseCommand msg of
			(Nothing, []) -> return (ReadUserInput, [], Nothing)
			(Nothing, str) -> return (PrintMessage, str, Nothing)
			(Just Quit, _) -> return (QuitGame, "Be seen you...", Nothing)
			(Just (Walk dir), _) -> do
								(walkMsg, newState) <- tryWalk dir curGS
								return (SaveState, walkMsg, newState)
			(Just Inventory, _) -> return (PrintMessage, showInventory inventory, Nothing)
			(Just Look, _) -> return (PrintMessage, lookAround currentRoom roomObjects, Nothing)
			(Just (Investigate itmName), _) -> case canSeeObject (roomObjects ++ inventory) itmName of
					True -> return (PrintMessage, investigateObject itmName (roomObjects ++ inventory), Nothing)
					False -> return (PrintMessage, notVisibleObjectError itmName, Nothing)


run :: String -> GS ()
run msg = do
	(gameAction, str, maybeGameState) <- run' msg
	case gameAction of
		QuitGame -> ioOutMsgGS str >> return ()
		PrintMessage -> ioOutMsgGS str >> run ""
		ReadUserInput -> ioInMsgGS >>= run
		SaveState -> case maybeGameState of
				Just newState -> ioOutMsgGS str >> put newState >> run ""
				Nothing -> ioOutMsgGS str >> run ""

main :: IO ()
main = do
	putStrLn $ lookAround startRoom startRoomObjects
	x <- evalStateT (runGameState (run [])) initWorld
	putStrLn ""
		where
			startRoom = gsCurrentRoom $ initWorld
			startRoomObjects = locObjects . location $ startRoom