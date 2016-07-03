import System.Environment
import Data.Bits
import Data.Char
import qualified Data.ByteString.Lazy as BL

main :: IO ()
main = do
  args <- getArgs
  text <- return "This example text gets about 128 characters long if you consider the fact both lemurs and lamssasses need to get mentioned in it"
  font <- BL.readFile (args !! 0)
  putStrLn "MEMORY_INITIALIZATION_RADIX=2;"
  putStrLn "MEMORY_INITIALIZATION_VECTOR="

  let coeline x = 
        case toInteger x of
        0 -> "00"
        1 -> "01"
        2 -> "10"
        _ -> "11"

  mapM_ (\b -> (putStr $ coeline b) >> (putStrLn ",")) (BL.unpack $ BL.take 24064 font)

  let charcoe b = 
        do putStr $ coeline (b .&. 0x3)
           putStrLn ","
           putStr $ coeline ((shiftR b 2) .&. 0x3)
           putStrLn ","
           putStr $ coeline ((shiftR b 4) .&. 0x3)
           putStrLn ","
           putStr $ coeline ((shiftR b 6) .&. 0x3)

  mapM_ (\b -> (charcoe b) >> (putStrLn ",")) (map ord $ take 127 text)
  charcoe $ ord (text !! 127)
  putStrLn ";"

