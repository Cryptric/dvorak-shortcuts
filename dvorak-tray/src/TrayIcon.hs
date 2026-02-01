{-# LANGUAGE OverloadedStrings #-}

module TrayIcon (TrayIconParams(..), TrayIcon, mkTrayIcon, registerTray, setIcon) where

import DBus
import DBus.Client
import Data.Int (Int32)
import Data.IORef
import System.Posix.Process (getProcessID)
import Text.Printf (printf)

data TrayIconParams = TrayIconParams {
    paramIconName :: String,
    paramTitle :: String,
    paramActivateHandler :: Int32 -> Int32 -> IO (),
    paramSecondaryActivateHandler :: Int32 -> Int32 -> IO (),
    paramScrollHandler :: Int32 -> String -> IO ()
}

data TrayIcon = TrayIcon {
    iconName :: IORef String,
    trayId :: String,
    trayBusName :: BusName,
    trayTitle :: String,
    trayActivateHandler :: Int32 -> Int32 -> IO (),
    traySecondaryActivateHandler :: Int32 -> Int32 -> IO (),
    trayScrollHandler :: Int32 -> String -> IO ()
}

mkTrayIcon :: TrayIconParams -> (IO TrayIcon)
mkTrayIcon (TrayIconParams { paramIconName = pIconName, paramTitle = pTitle, paramActivateHandler = pActivateHandler, paramSecondaryActivateHandler = pSecondaryActivateHandler, paramScrollHandler = pScrollHandler }) = do
  pid <- getProcessID
  iconRef <- newIORef pIconName
  let busName = busName_ $ printf "org.kde.StatusNotifierItem-%d-1" (fromIntegral pid :: Int)
  return $ TrayIcon iconRef (printf (pTitle ++ "%d") (fromIntegral pid :: Int)) busName pTitle pActivateHandler pSecondaryActivateHandler pScrollHandler



trayInterface :: TrayIcon -> Interface
trayInterface tray = defaultInterface
  { interfaceName = "org.kde.StatusNotifierItem"
  , interfaceProperties =
      [ readOnlyProperty "Category" (return ("ApplicationStatus" :: String))
      , readOnlyProperty "Id" (return $ trayId tray)
      , readOnlyProperty "Status" (return ("Active" :: String))
      , readOnlyProperty "IconName" (readIORef $ iconName tray)
      , readOnlyProperty "Title" (return (trayTitle tray :: String))
      , readOnlyProperty "ItemIsMenu" (return False)
      , readOnlyProperty "Menu" (return ("/" :: ObjectPath))
      ]
  , interfaceMethods =
      [ autoMethod "Activate" (trayActivateHandler tray)
      , autoMethod "SecondaryActivate" (traySecondaryActivateHandler tray)
      , autoMethod "Scroll" (trayScrollHandler tray)
      ]
  }

registerTray :: Client -> TrayIcon -> IO ()
registerTray client tray = do
  let objPath = "/StatusNotifierItem"
  export client objPath (trayInterface tray)
  _ <- requestName client (trayBusName tray) [nameAllowReplacement, nameReplaceExisting]
  _ <- call_ client (methodCall "/StatusNotifierWatcher"
                                "org.kde.StatusNotifierWatcher"
                                "RegisterStatusNotifierItem")
    { methodCallDestination = Just "org.kde.StatusNotifierWatcher", methodCallBody = [toVariant $ formatBusName (trayBusName tray)]}

  putStrLn $ "Registered tray icon: " ++ formatBusName (trayBusName tray)

setIcon :: Client -> TrayIcon -> String -> IO ()
setIcon client tray newIcon = do
  writeIORef (iconName tray) newIcon
  emit client (signal "/StatusNotifierItem" "org.kde.StatusNotifierItem" "NewIcon")


