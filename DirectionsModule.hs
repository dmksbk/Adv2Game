module DirectionsModule where

import Types
import Locations
import Tools

directionFromCommand :: String -> Direction
directionFromCommand x = case upString(x) of
							"NORTH" -> North
							"SOUTH" -> South
							"WEST" -> West
							"EAST" -> East
							_ -> NoDirection

directionsToString :: Directions -> String
directionsToString [] = []
directionsToString (dir:dirs) = show dir ++ case null(dirs) of
												True -> []
												False -> ", " ++ directionsToString dirs
							
describeDirections :: Room -> String
describeDirections room = "You can go " ++ directionsToString (getRoomDirections room) ++ "."

getPathDirections :: Paths -> Directions
getPathDirections [] = []
getPathDirections (x:xs) = [pathDir $ x] ++ getPathDirections xs

getRoomDirections :: Room -> Directions
getRoomDirections room = getPathDirections . getLocationPaths . location $ room

canWalk :: Room -> Direction -> Bool
canWalk room dir = dir `elem` (getRoomDirections room)

pathOnDirection :: Direction -> Path -> Bool
pathOnDirection dir p = (pathDir $ p) == dir

pathsOnDirection :: Room -> Direction -> Paths
pathsOnDirection room dir = filter (pathOnDirection dir) (getLocationPaths . location $ room)

walkToDir :: Room -> Direction -> Room
walkToDir room dir = pathRoom . head $ (pathsOnDirection room dir)