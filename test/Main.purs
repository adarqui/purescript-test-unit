module Test.Main where

import Prelude
import Test.Unit.Assert as Assert
import Control.Monad.Aff (makeAff)
import Control.Monad.Aff.AVar (AVAR)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Console (CONSOLE)
import Control.Monad.Eff.Random (RANDOM)
import Test.QuickCheck (Result, (===))
import Test.Unit (suite, Test, TIMER, test, timeout)
import Test.Unit.Console (TESTOUTPUT)
import Test.Unit.Main (runTest)
import Test.Unit.QuickCheck (quickCheck)
import Control.Monad.Eff.Class (liftEff)
import Test.Unit.Console (print)

unresolved :: forall e. Test e
unresolved = makeAff \_ _ -> pure unit

theCommutativeProperty :: Int -> Int -> Result
theCommutativeProperty a b = (a + b) === (b + a)

main :: forall e. Eff (timer :: TIMER, avar :: AVAR, console :: CONSOLE, random :: RANDOM, testOutput :: TESTOUTPUT | e) Unit
main = runTest do
  {-- test "basic asserts" do --}
  {--   Assert.assert "wasn't true" true --}
  {--   Assert.assertFalse "wasn't false" false --}
  {-- test "timeout" do --}
  {--   Assert.expectFailure "didn't time out" $ timeout 100 unresolved --}
  {-- test "equal" do --}
  {--   Assert.equal "omg" "omg" --}
  {--   Assert.expectFailure "should be unequal" $ Assert.equal "omg" "wat" --}
  {-- test "quickcheck" do --}
  {--   quickCheck theCommutativeProperty --}
  suite "a test suite" do
    test "a test in a test suite" do
      liftEff $ print "hi1"
      liftEff $ print "hi2"
      Assert.equal "lol" "lol"
