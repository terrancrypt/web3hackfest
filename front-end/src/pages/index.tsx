import Head from "next/head";
import Link from "next/link";

export default function Home() {
  return (
    <>
      <Head>
        <title>TC Protocol</title>
      </Head>
      <main className="container mx-auto flex items-center justify-center">
        <div>
          <h1>
            Welcome to the TCProtocol. A project built by{" "}
            <a
              href="https://github.com/terrancrypt"
              target="_blank"
              className="underline"
            >
              terrancrypt
            </a>{" "}
            to participate in{" "}
            <a
              href="https://web3-hackfest.devfolio.co/"
              target="_blank"
              className="underline"
            >
              Web3Hackfest
            </a>
          </h1>
          <p>
            To learn about the protocol, please read the{" "}
            <a
              href="https://github.com/terrancrypt/web3hackfest/tree/master#about"
              target="_blank"
              className="underline"
            >
              documentation
            </a>
            .
          </p>
          <p>
            To use the protocol, please get the necessary tokens before use.
          </p>
          <p>
            You need to get ETH at{" "}
            <a
              href="https://sepoliafaucet.com/"
              target="_blank"
              className="underline"
            >
              Alchemy Sepolia Faucet
            </a>{" "}
            for transaction fees for borrow TCUSD stablecoin.
          </p>
          <p>
            Some other collateral are WETH, WBTC you can get in{" "}
            <Link href="/faucet" className="underline">
              Faucet
            </Link>
            .
          </p>
        </div>
      </main>
    </>
  );
}
