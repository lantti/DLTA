import System.Environment
import Data.Bits
import Data.Char
import qualified Data.ByteString.Lazy as BL

main :: IO ()
main = do
  args <- getArgs
  font <- BL.readFile (args !! 0)
  putStrLn "font"
  mapM_ (\b -> (putStr $ show b) >> (putStr ",")) (packFontBytes $ BL.unpack $ BL.take 23552 font)
  putStrLn ""

packFontBytes (b0:b1:b2:b3:bs) = ((shiftL b3 6) .|. (shiftL b2 4) .|. (shiftL b1 2) .|. b0) : (packFontBytes bs)
packFontBytes bs = []
