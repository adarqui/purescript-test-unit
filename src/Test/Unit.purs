module Test.Unit
  ( Test(..)
  , TestF(..)
  , Group(..)
  , TestGroup
  , TestSuite
  , TIMER
  , success
  , failure
  , timeout
  , test
  , suite
  , collectTests
  , collectResults
  , collectErrors
  , keepErrors
  ) where

import Prelude

import Control.Monad.Eff.Class (liftEff)
import Test.Unit.Console (print)
import Control.Alt ((<|>))
import Control.Monad.Aff (Aff, attempt, makeAff, forkAff, cancelWith)
import Control.Monad.Aff.AVar (makeVar, killVar, putVar, takeVar, AVAR)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Exception (error, Error)
import Control.Monad.Free (runFreeM, Free, liftF)
import Control.Monad.Writer (execWriter, tell)
import Data.Either (Either(Left), either)
import Data.Foldable (foldl)
import Data.List (snoc, singleton, List(Nil))
import Data.Traversable (for)
import Data.Tuple (Tuple(Tuple))
import Debug.Trace (spy)

foreign import data TIMER :: !

type Test e = Aff e Unit

-- | The basic value for a succeeding test.
success :: forall e. Test e
success = makeAff \_ succeed -> succeed unit

-- | Make a failing test, given a reason for the failure.
failure :: forall e. String -> Test e
failure reason = makeAff \fail _ -> fail $ error reason

foreign import setTimeout :: forall e a. Int -> Eff (timer :: TIMER | e) a -> Eff (timer :: TIMER | e) Unit

makeTimeout :: forall e. Int -> Aff (timer :: TIMER | e) Unit
makeTimeout time = makeAff \fail _ -> setTimeout time $ fail $ error $ "test timed out after " <> show time <> "ms"

pickFirst :: forall e. Test (avar :: AVAR | e) -> Test (avar :: AVAR | e) -> Test (avar :: AVAR | e)
pickFirst t1 t2 = do
  va <- makeVar
  c1 <- forkAff $ attempt t1 >>= either (killVar va) (putVar va)
  c2 <- forkAff $ attempt t2 >>= either (killVar va) (putVar va)
  let k = spy "_pickFirst_"
  (takeVar va) `cancelWith` (c1 <> c2)

-- | Set a test to fail after a given number of milliseconds.
timeout :: forall e. Int -> Test (timer :: TIMER, avar :: AVAR | e) -> Test (timer :: TIMER, avar :: AVAR | e)
timeout time t = t `pickFirst` (makeTimeout time)



data Group e = Group String (TestSuite e)

data TestF e a = TestGroup (Group e) a
             | TestUnit String (Test e) a

type TestGroup e = Free (TestF e)
type TestSuite e = TestGroup e Unit
type TestUnit e = TestF e Unit

instance functorTestF :: Functor (TestF e) where
  map f (TestGroup g a) = TestGroup g (f a)
  map f (TestUnit l t a) = TestUnit l t (f a)

-- | Define a test suite, which can contain a number of nested suites
-- | as well as tests.
suite :: forall e. String -> TestSuite e -> TestSuite e
suite label tests = do
--  let k = spy "_suite_"
--  let z = spy label
--  let z2 = spy tests
  liftF $ TestGroup (Group label tests) unit

-- | Define a labelled test.
test :: forall e. String -> Test e -> TestSuite e
test l t = do
--  let k = spy "_test_"
  liftF $ TestUnit l t unit



-- | Walk a test suite and collect all the tests inside it as a flat sequence.
collectTests :: forall e. TestSuite e -> List (Tuple (List String) (Test e))
collectTests = execWriter <<< runFreeM (runSuiteItem Nil)
  where runSuiteItem path (TestUnit label t rest) = do
          let k = spy "_collectTests TestUnit_"
          tell $ singleton $ Tuple (snoc path label) t
          pure rest
        runSuiteItem path (TestGroup (Group label children) rest) = do
          let k = spy "_collectTests TestGroup_"
          runFreeM (runSuiteItem (snoc path label)) children
          pure rest

-- | Run a test suite and collect each test result in a flat list.
collectResults :: forall e. TestSuite e -> Aff e (List (Tuple (List String) (Either Error Unit)))
collectResults tests = do
  let k = spy "_collectResults_"
  let z = spy tests
  for (collectTests tests) $ \_ -> do
    let z2 = spy "for"
    pure unit
--  pure Nil
  for (collectTests tests) run
  where run (Tuple label t) = Tuple label <$> attempt t

-- | Filter successes out of a list of test results.
keepErrors :: List (Tuple (List String) (Either Error Unit)) -> List (Tuple (List String) Error)
keepErrors = foldl run Nil
  where run s (Tuple label (Left err)) = snoc s $ Tuple label err
        run s _ = s

-- | Run a test suite and collect failing tests in a flat list.
collectErrors :: forall e. TestSuite e -> Aff e (List (Tuple (List String) Error))
-- collectErrors = collectResults >>> map keepErrors
collectErrors t = do
  let k = spy "_collectErrors_"
  (map keepErrors <$> collectResults) t
--  pure (map keepErrors z)
--  collectResults >>> map keepErrors
