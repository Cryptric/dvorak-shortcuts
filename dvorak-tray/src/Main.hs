#!/usr/bin/env stack
{- stack script
  --resolver lts-22.6
  --system-ghc
  --package dbus
  --package unix
  --package base
-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import DBus
import DBus.Client
import Control.Monad (forever, void)
import Control.Concurrent (threadDelay)
import Data.Int (Int32)
import Data.IORef

import TrayIcon (TrayIconParams(..), mkTrayIcon, registerTray, setIcon)


enableMethodCall :: MethodCall
enableMethodCall  = (methodCall "/com/dvorak/Keyboard" "com.dvorak.Keyboard" "Enable")  { methodCallDestination = Just "com.dvorak.Keyboard" }
disableMethodCall :: MethodCall
disableMethodCall = (methodCall "/com/dvorak/Keyboard" "com.dvorak.Keyboard" "Disable") { methodCallDestination = Just "com.dvorak.Keyboard" }

statusMatchRule :: MatchRule
statusMatchRule = matchAny {
    matchInterface = Just "com.dvorak.Keyboard",
    matchMember    = Just "Status",
    matchPath      = Just "/com/dvorak/Keyboard"
}

secondaryActivateHandler :: Int32 -> Int32 -> IO ()
secondaryActivateHandler _ _ = return ()

scrollHandler :: Int32 -> String -> IO ()
scrollHandler _ _ = return ()

main :: IO ()
main = do
    enabledRef <- newIORef True

    systemClient <- connectSystem
    sessionClient <- connectSession

    let activateHandler _ _ = do
          enabled <- readIORef enabledRef
          void $ call systemClient (if enabled then enableMethodCall else disableMethodCall)

    let trayIconParams = TrayIconParams {
        paramIconName                 = "input-keyboard-virtual-on",
        paramTitle                    = "dvorak",
        paramActivateHandler          = activateHandler,
        paramSecondaryActivateHandler = secondaryActivateHandler,
        paramScrollHandler            = scrollHandler
    }

    tray <- mkTrayIcon trayIconParams
    registerTray sessionClient tray

    let statusCallback sig =
            case signalBody sig of
                (v:_) -> case fromVariant v :: Maybe Bool of
                    Just enabled -> do
                        writeIORef enabledRef enabled
                        setIcon sessionClient tray $ if not enabled then "input-keyboard-virtual-on" else "input-keyboard-virtual-off"
                    Nothing -> return ()
                [] -> return ()

    _ <- addMatch systemClient statusMatchRule statusCallback
    _ <- forever $ threadDelay 1000000

    disconnect sessionClient
    disconnect systemClient
