{-# LANGUAGE Arrows #-}
module Tutorial1 (
  main
  -- * Tutorial 1 -- Coinslot
  -- ** Introduction
  -- $intro

  -- ** Overview
  -- $overview

  -- ** Program Structure
  -- $structure

  -- ** IO
  -- $io

  -- ** Logic
  -- $logic
  ) where

import FRP.Timeless
import Control.Concurrent
import System.IO

-- $intro
-- This series of tutorial aims at its corresponding major version of Timeless. For example,
-- a version number of 1.x.x.x means it should be compatible with Timeless version >= 1 and < 2.
--
-- As a project goal, this tutorial series will also aid the development and refactor of Timeless.
-- Major breakage is unlikely if you don't use underlying 'Signal's directly. However, if you do,
-- good luck. And it is important that, if you have seen my timeless-0.9.x.x tutorials, they would
-- probably still work with modifications. However, that version is way too primitive and messy to
-- write, and doesn't really give any advantage of FRP, and gave me much more headache than writing
-- using "normal" methods.
--
-- This series should hopefully guide you to be familiar with "my" way of FR. Of course, I do not
-- have real serious UI experiences, so I am also learning. Again, expect radical changes, but the
-- code should still work.
--
-- Feel free to skip this section if you don't want to read stories.
--
-- Now, why would I write Timeless?
--
-- Because I intuitively think FRP is the way to go. I have read /Functional Reactive Programming/,
-- and I tried to learn Netwire because of the nice Arrow syntax.
--
-- And of course, Timeless is forked originally from Netwire 5 because it is unmaintained and incomplete.
-- And Timeless is just a random name I gave it. As of version 1, Timeless is really, timeless,
-- because I removed the Session(with time information) that feeds into every 'Signal', as inherited
-- from Netwire. The reason is, I think this makes reasoning with purity much harder, and I'd rather
-- explicitly put down an IO signal just to read the time. That should compose much better.
--
-- Timeless 1 imitates the /primitives/ like /Sodium/ as described in the book
-- /Functional Reactive Programming/. Of course, since Timeless works on 'Arrows' instead of end
-- points, exact details are different, and will be shown in the tutorials.
--
-- Backstory nonsense is enough, and I will start to explain how to design a coinslot machine.

-- $overview
-- This program does one thing.
--
-- > Current Coins: 0
-- > >>> Hello
-- > Current Coins: 0
-- > >>> insert
-- > Current Coins: 1
-- > >>> insert
-- > Current Coins: 2
-- > >>>
--
--
-- That's it. There is only one command, @insert@, which increments the coin coint. Everything else
-- be ignored. Now proceed to writing the program!
--
-- $structure
-- As described in the book I mentioned multiple times, any Timeless program have two types of
-- primitive signals: 'Stream' and 'Cell'. Names are from the book directly. 'Stream' represents
-- a stream of events, which can arriveat any time, and only contains value when it is fired.
-- 'Cell' represents continuous value in time, therefore always has a value. In a program,
-- 'Cell's are used to store state, while 'Stream's model interaction. Detailed usage of primitives
-- will be explained on the go.
--
-- Also notice that most primitives are /transparent/ or /atomic/, which means the output value is
-- immediately available. Except for the 'delay' primitive, which delays the information for an
-- infinitesimal amount of time. For those have worked with state machines on FPGA, it should be
-- obvious that if all primitives give delay, nasty timing design must be considered. This defeats
-- the reason to use FRP at all, and makes programming as hard as designing hardware.
--
-- The atomic property follows that, nothing should ever block, or ever cause any side effects inside
-- a 'Stream' or 'Cell'. Description of performing side effects will be shown in next section.
-- In addition, anything that blocks, or takes significant time should be forked to another thread,
-- and use 'MVar' or alike to communicate. Detailed
-- explanation is in the next section.

-- $io
-- To make the program easier to test, the first part to complete is IO. Let's do the simpler first:
-- printing.
--
-- We are not using any fancy ANSI terminal things, just a good old command line. Therefore, the simple
-- 'putStr' function is enough, which updates every time Enter is pressed. Of course, `getLine` will
-- echo input, so that part is automatically solved.
--
-- Since this is a simple terminal, we should not print information continuously, or garbage will
-- quickly flood the console. This gives the decision to make this output a 'Stream', as it is
-- discrete. In this series, I will always prepend @s@ to the name of a 'Stream'.
--
-- > sPutStrSink = sinkS $ \s -> putStr s >> hFlush stdout
--
-- Time for some explanation. 'StreamSink' can be seen as a black box which devours value and spits
-- nothing out. Perfect for performing side effects, because the effects will never be known to
-- the rest of the program! Think @IO ()@. And in fact, Timeless provides:
--
-- > sinkS :: (a -> IO ()) -> StreamSink a
--
-- Therefore, the output is very straightforward. Notice that 'stdout' should be flushed, or the
-- last line will not show up in terminal.
--
-- Next, the input is slightly more complicated. To easily get a command, 'getLine' is the most
-- straightforward way. However, it blocks!
--
-- Now there is a good news. Haskell threads are virtually free, so use as many as you can! Since
-- we are communicating using an 'MVar', we need:
--
-- > sMVarSource mvar = sourceS $ tryTakeMVar mvar
--
-- This 'Stream' fires when a value is present in the 'MVar'. How does that work? Look at the timeless
-- provided constructor:
--
-- > sourceS :: IO (Maybe b) -> StreamSource b
--
-- As you might guess, when the IO action returns @Just b@, the 'Stream' fires with value 'b'.
-- @tryTakeMVar@ is a perfect function to fit.
--
-- Of course, we need to get that 'MVar' from somewhere, which means a thread must be spawned before
-- the network is constructed and ran.
--
--
-- > initPrint = do
-- >   mvar <- newEmptyMVar
-- >   forkIO $ loop mvar
-- >   return mvar
-- >     where
-- >       loop mvar = do
-- >         s <- getLine
-- >         putMVar mvar s
-- >         loop mvar
--
--
-- This action will spawn the thread needed, and returns the 'MVar'. It is possible to do the
-- initialization with just timeless(as I did in my previous versions), but it involves using
-- 'Signal's directly, and adds quite some complexity to the final network. For now, use this
-- simpler way.
--
-- Now there is input and output. Let's test it!
--
--
-- > testBox mvar = proc () -> do
-- >   str <- sMVarSource mvar -< ()
-- >   sPutStrSink -< str
--
--
-- "Box" is my name for a network of signals which is totally opaque. The box driver just keeps
-- updating the box, and only cares whether it is shut down. In this tutorial, the "shut down"
-- part is ignored.
--
-- If you have seen the 'Arrow' syntax before, the flow should be straightforward. If you have
-- not, just remember that 'proc' is like lambda, and the '()' is the single input that will
-- be fed into the 'Arrow'. Here, since 'testBox' is a black box, the only input is '()',
-- which is "no information except for its presence". Another important fact is that, the part
-- between @<-@ and @-<@ are the Arrows themselves, while the outer part are their inputs and
-- outputs. The Arrow network is static on compile time, and the "inner" and "outer" part have
-- different scope, so do not try to reference variables between the two parts. One last note
-- is that 'Arrow' does not have currying. Unfortunately, currying is a special property of
-- functions, not the more generic Arrows. If you need more than one input, use a tuple or some
-- ADT.
--
-- To explain the box, the source is driven by the input @()@. This is mandatory since every
-- arrow needs an input. It outputs to @str@, which is fed into the sink arrow. The box
-- is driven as follows:
--
--
-- > main = do
-- >   mvar <- initPrint
-- >   runBox $ testBox mvar
--
--
-- Initialization is performed, and box is driven. Done!
--
-- The final result is a program that echos lines of input.

-- $logic
-- First, we need to parse the command. Since we don't have any fancy function except for
-- incrementing, parsing the command to be a 'Stream' of '()' is enough. This stream should
-- fire whenever the command is "insert", so:
--
-- > parse "insert" = Just ()
-- > parse _ = Nothing
--
-- Bingo! Next, we need to store the current count of coins.
--
-- > accumulator (_, coin) = coin + 1
--
-- The reason to do this is, Timeless gives a helper to construct a state:
--
-- > state :: s -> ((a, s) -> s) -> StreamCell a s
--
-- 'StreamCell' just means that it takes a 'Stream' as input, and outputs as a 'Cell'.
-- The first parameter is the initial value, while the second is a function of state transition.
-- Of course, @s@ is the state, and @a@ is the event. Here, 'accumulator' will count up
-- whenever the input is fired.
--
-- Next, we need to display the coin count, so we need a string.
--
-- > display coin = "Current coins: " ++ (show coin) ++ "\n>>> "
--
-- This function gives the string to display current coin count, and the prompt.
--
-- FInally, we are coming to the point to print the screen. However, there is a problem.
--
-- Remember we said that display is updated when Enter is pressed?
--
-- What about when the program just started?
--
-- This problem is solved in two parts.
--
-- First, since we need a 'Stream' to display, some sort of sampler is needed. This
-- 'Signal' will be used:
--
-- > sample :: Signal IO (Maybe a, b) (Maybe b)
--
-- I havn't introduced 'Signal' because using that directly will mess up the code. For now,
-- just understand that 'sample' takes two input, when @Stream a@ fires, @Cell b@ would be
-- sampled and fired on the Stream output.
--
-- With this in mind, we need some trigger 'Stream' that fires once on startup, and
-- on every subsequent Enter keypress.
--
-- Nicely, Timeless has the following 'Stream' which does exactly as advertised:
--
-- > onceS :: b -> StreamSource b
--
-- The two triggers must be merged somehow. And here is the signal:
--
-- > mergeSP :: Signal IO (Maybe a, Maybe a) (Maybe a)
--
-- It is easy to guess that this 'Signal' takes two 'Stream's as input, and outputs one
-- 'Stream'. More specifically, it prioritizes the first stream in case there is a
-- simultaneous arrival.
--
-- With these tools we can finally construct the real box.
--
--
-- > box mvar = proc () -> do
-- >   sCommand <- sMVarSource mvar -< ()
-- >   sTrigger <- arrS (const ()) -< sCommand
-- >   sAccumTrig <- arr (>>=parse) -< sCommand
-- >   cCoin <- state 0 accumulator -< sAccumTrig
-- >   cDisplay <- arr display -< cCoin
-- >   sInitTrig <- onceS () -< ()
-- >   sDispTrig <- mergeSP -< (sInitTrig, sTrigger)
-- >   sDisplay <- sample -< (sDispTrig, cDisplay)
-- >   sPutStrSink -< sDisplay
--
--
-- There are quite a lot going on. The code just does what it looks like, but there are things to note.
-- As before, the IO arrows are easy to find, with input
-- stored in @sCommand@ and final output in @sDisplay@. @sTrigger@ simply converts
-- each input event into the information-less '()', while @sAccumTrig@ fires when
-- coin is inserted. The display is triggered by @sDispTrig@, which merges @sInitTrig@
-- and @sTrigger@. Of course, @sInitTrig@ fires only once on startup.
--
-- Now, run the program!



sMVarSource mvar = sourceS $ tryTakeMVar mvar

initPrint :: IO (MVar String)
initPrint = do
  mvar <- newEmptyMVar
  forkIO $ loop mvar
  return mvar
    where
      loop mvar = do
        s <- getLine
        putMVar mvar s
        loop mvar

sPutStrSink = sinkS $ \s -> putStr s >> hFlush stdout

display coin = "Current coins: " ++ (show coin) ++ "\n>>> "

accumulator :: ((), Integer) -> Integer
accumulator (_, coin) = coin + 1

parse "insert" = Just ()
parse _ = Nothing

box mvar = proc () -> do
  sCommand <- sMVarSource mvar -< ()
  sTrigger <- arrS (const ()) -< sCommand
  sAccumTrig <- arr (>>=parse) -< sCommand
  cCoin <- state 0 accumulator -< sAccumTrig
  cDisplay <- arr display -< cCoin
  sInitTrig <- onceS () -< ()
  sDispTrig <- mergeSP -< (sInitTrig, sTrigger)
  sDisplay <- sample -< (sDispTrig, cDisplay)
  sPutStrSink -< sDisplay

testBox mvar = proc () -> do
  str <- sMVarSource mvar -< ()
  sPutStrSink -< str

main :: IO ()
main = do
  mvar <- initPrint
  --runBox $ testBox mvar
  runBox $ box mvar
