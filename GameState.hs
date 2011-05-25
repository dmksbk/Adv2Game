module GameState where

import Types
import Locations
import Objects

import Text.Printf(printf)

initGameState :: GameState
initGameState = GameState {
	gsLocations = initialLocations,
	gsCurrentRoom = initialRoom,
	gsObjects = initialObjects
}

tryExamineObject :: Object -> GameAction
tryExamineObject obj = PrintMessage (objectDescription' obj)

tryWalk :: Location -> Direction -> GameState -> GameAction
tryWalk loc dir curGS@(GameState locs _ objects) =
		case walk loc dir locs of
			(Nothing, str) -> PrintMessage str
			(Just walkedLoc, str) -> SaveState newGS (str ++ "\n" ++ msg)
				where
					(msg, newWalkedLoc) = describeLocation walkedLoc (locationObjects walkedLoc objects)
					newLocs = updateLocations newWalkedLoc locs
					newGS = curGS {gsLocations = newLocs, gsCurrentRoom = locRoom newWalkedLoc}
					


tryTakeS :: String -> Objects -> GameState -> GameAction
tryTakeS str objects curGS = case parseObject str objects of
							Right obj -> tryTake obj curGS
							Left str -> PrintMessage str

tryTake :: Object -> GameState -> GameAction
tryTake obj curGS = let objects = gsObjects curGS
					 in case pickup obj of
						(Just newObj, msg) -> SaveState curGS {gsObjects = (replaceObject newObj objects)} msg
						(Nothing, msg) -> PrintMessage msg

-- "���������" ��������� ������� Weld. ���� ����� ������ ����� �����, �� ����������� � ���������, ���� ����� ������, �������� � �������.
-- ��� ������ ������� ��������� �� �������.
applyWeld :: Object -> Object -> Object -> GameState -> (String, GameState)
applyWeld o1 o2 weldedO curGS =
		let
			curRoom = gsCurrentRoom curGS
			objects = gsObjects curGS
			(maybePickedUp, _) = pickup weldedO
			weldedInCurrentRoom = weldedO {objectRoom = curRoom}
			newO1 = o1 {objectRoom = NoRoom}
			newO2 = o2 {objectRoom = NoRoom}
			(msg, updatedObjects) =
				case maybePickedUp of
					Just newObj -> (printf "\n%s added to your Inventory." (showObject newObj),
									replaceObjectList [newObj, newO1, newO2] objects)
					Nothing -> ("", replaceObjectList [weldedInCurrentRoom, newO1, newO2] objects)
		in (msg, curGS {gsObjects = updatedObjects})

tryWeld :: Object -> Object -> GameState -> GameAction
tryWeld obj1 obj2 curGS = case weld obj1 obj2 of
			Just (newObj, str) ->
				let (msg, newGS) = applyWeld obj1 obj2 newObj curGS in
				SaveState newGS (str ++ "\n" ++ msg)
			Nothing -> PrintMessage (failureWeldObjectsError obj1 obj2)

tryOpenS :: String -> Objects -> GameState -> GameAction
tryOpenS str objects curGS = case parseObject str objects of
								Right obj -> tryOpen obj curGS
								Left str -> PrintMessage str

tryOpen :: Object -> GameState -> GameAction
tryOpen o gs@(GameState _ _ objects) = case open o of
											(Nothing, msg) -> PrintMessage msg
											(Just obj, msg)-> SaveState (gs {gsObjects = replaceObject obj objects}) msg