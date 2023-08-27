import {
  depositCollateral,
  engineContract,
  getUSDValueOfCollateral,
  getVaultAddress,
} from "@/contract-functions/interactEngineContract";
import { Form, Slider, Spin, message } from "antd";
import { useRouter } from "next/router";
import React, { useState, useEffect } from "react";
import { getAccount, waitForTransaction } from "@wagmi/core";
import {
  getTokenBalanceOf,
  tokenApprove,
} from "@/contract-functions/interactTokenContract";
import { formatEther } from "ethers";
interface Step1Props {
  current: number;
  setCurrent: (value: number) => void;
}

const Step1: React.FC<Step1Props> = ({ current, setCurrent }) => {
  const {
    query: { vaultId },
  } = useRouter();
  const account = getAccount();
  const [collateral, setCollateral] = useState("");
  const [inputValue, setInputValue] = useState<bigint>();
  const [tcUSDValue, setTcUSDValue] = useState<string>();
  const [txLoading, setTxLoading] = useState(false);
  const [txHash, setTxHash] = useState("");
  const [accountBalance, setAccountBalance] = useState<bigint>();
  const [amountCanBorrow, setAmountCanBorrow] = useState<bigint>();
  const [displayInputValue, setDisplayInputValue] = useState<string>();

  const fetchData = async () => {
    try {
      if (vaultId) {
        const collateral = await getVaultAddress(Number(vaultId));
        let accountBalance;
        let collateralPrice;
        let amountTcUSDCanBorrow: bigint;
        if (account.connector != undefined) {
          accountBalance = await getTokenBalanceOf(account.address, collateral);
          collateralPrice = await getUSDValueOfCollateral(collateral, 1);
          if (accountBalance != null) {
            setAccountBalance(accountBalance);
            amountTcUSDCanBorrow =
              (collateralPrice * accountBalance * BigInt(45)) / BigInt(100);
            setAmountCanBorrow(amountTcUSDCanBorrow);
          }
        }
        if (collateral != null) {
          setCollateral(collateral);
        }
      }
    } catch (error) {
      console.log(error);
      message.error("Cannot fetch data!");
    }
  };

  const deposit = async (amount: bigint) => {
    try {
      setTxLoading(true);
      if (vaultId) {
        const isApprove: boolean = await approveEngine(amount);
        if (isApprove == true) {
          const hash = await depositCollateral(
            Number(vaultId),
            amount,
            account.address as any
          );
          if (hash == null) {
            throw message.error("Transaction Error");
          } else {
            setTxHash(hash as any);
            const wait: any = await waitForTransaction({
              confirmations: 1,
              hash: hash as any,
            });
            if (wait.status == "success") {
              message.success("Approve success!");
              setCurrent(current + 1);
            } else {
              throw message.error("Transaction failed");
            }
          }
        }
      }
    } catch (error) {
      console.log(error);
      message.error("Transaction failed");
    } finally {
      setTxLoading(false);
    }
  };

  const approveEngine = async (amount: bigint): Promise<boolean> => {
    try {
      const hash = await tokenApprove(
        account.address,
        collateral,
        engineContract.address,
        amount
      );
      if (hash == null) {
        return false;
      }
      const wait: any = await waitForTransaction({
        confirmations: 1,
        hash: hash as any,
      });
      if (wait.status == "success") {
        message.success("Approve success!");
        return true;
      } else {
        message.error("Transaction failed");
        return false;
      }
    } catch (error) {
      message.error("Cannot approve");
      return false;
    }
  };

  const onFinish = () => {
    if (inputValue != undefined) {
      deposit(BigInt(inputValue));
    }
  };

  const onChange = (value: any) => {
    if (isNaN(value)) {
      return;
    }
    const numericValue = BigInt(value);
    setInputValue(numericValue);
    setDisplayInputValue(formatEther(BigInt(numericValue)));
    if (accountBalance != undefined && accountBalance !== BigInt(0)) {
      let percentage: bigint = (numericValue * BigInt(100)) / accountBalance;
      if (amountCanBorrow != undefined) {
        const newTcUSDValue = (amountCanBorrow * percentage) / BigInt(100);
        setTcUSDValue(formatEther(newTcUSDValue));
      }
    }
  };

  useEffect(() => {
    fetchData();
  }, [account.status]);

  return (
    <div className="px-32">
      {!txLoading ? (
        <Form onFinish={onFinish} layout="vertical">
          <div className="flex pt-16">
            <Form.Item name="slider" className="flex-grow" initialValue={1}>
              <Slider
                min={1}
                max={Number(accountBalance)}
                onChange={onChange}
                value={typeof inputValue === "number" ? inputValue : 0}
                tooltip={{ open: false }}
              />
            </Form.Item>
          </div>

          <p className="text-white w-full pb-3 text-left">
            Amount collateral:{" "}
            {displayInputValue ? Number(displayInputValue).toFixed(2) : 0}
          </p>
          <p className="text-white w-full pb-10 text-left">
            Amount tcUSD Can Borrow:{" "}
            {tcUSDValue ? Number(tcUSDValue).toFixed(2) : 0}
          </p>

          <div className="flex justify-between items-center">
            <Form.Item>
              <button
                type="submit"
                className="p-4 rounded-xl bg-black text-white hover:scale-90 transition-all"
              >
                Deposit
              </button>
            </Form.Item>
            <div className="flex justify-center items-center w-[50px] whitespace-nowrap gap-2 pb-8 pr-20">
              <p className="text-white">Had deposited?</p>{" "}
              <button
                className="px-4 py-2 rounded-xl border text-white hover:scale-90 transition-all"
                onClick={() => setCurrent(current + 1)}
              >
                Next
              </button>
            </div>
          </div>
        </Form>
      ) : (
        <>
          <div className="space-x-4">
            <Spin size="large" spinning={txLoading} />
            {txHash != "" ? (
              <a
                className="bg-black tex-white rounded-lg p-2 text-sm hover:scale-90"
                target="_blank"
                href={`https://sepolia.etherscan.io/tx/${txHash}`}
              >
                view your transaction
              </a>
            ) : (
              <></>
            )}
          </div>
        </>
      )}
    </div>
  );
};

export default Step1;
