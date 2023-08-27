import {
  createPosition,
  getTcUSDAmountCanBorrow,
  getUserVaultBalance,
} from "@/contract-functions/interactEngineContract";
import { getTokenBalanceOf } from "@/contract-functions/interactTokenContract";
import { Form, Slider, Spin, message } from "antd";
import { useRouter } from "next/router";
import React, { useState, useEffect } from "react";
import { getAccount, waitForTransaction } from "@wagmi/core";
import { formatEther } from "ethers";

interface Step2Props {
  current: number;
  setCurrent: (value: number) => void;
}

const Step2: React.FC<Step2Props> = ({ current, setCurrent }) => {
  const {
    query: { vaultId },
  } = useRouter();
  const account = getAccount();

  const [collateralBalance, setCollateralBalance] = useState<bigint>();
  const [displayCollateralValue, setDisplayCollateralValue] =
    useState<string>();
  const [collateralInput, setCollateralInput] = useState<bigint>();

  const [amountCanBorrow, setAmountCanBorrow] = useState<bigint>();
  const [displayAmountToBorrow, setDisplayAmountToBorrow] = useState<string>();
  const [amountBorrowInput, setAmountBorrowInput] = useState<bigint>();

  const [txLoading, setTxLoading] = useState(false);
  const [txHash, setTxHash] = useState("");

  const fetchData = async () => {
    try {
      if (vaultId) {
        if (account.connector != undefined) {
          const collateralBalance = await getUserVaultBalance(
            Number(vaultId),
            account.address as any
          );
          setCollateralBalance(collateralBalance);
          const amountCanBorrow = await getTcUSDAmountCanBorrow(
            Number(vaultId),
            account.address as any
          );
          setAmountCanBorrow(amountCanBorrow);
        }
      }
    } catch (error) {
      console.log(error);
      message.error("Cannot fetch data!");
    }
  };

  const borrow = async (collateralAmount: number, tcUSDAmount: number) => {
    try {
      setTxLoading(true);
      if (vaultId) {
        const hash = await createPosition(
          Number(vaultId),
          collateralAmount,
          tcUSDAmount,
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
            message.success("Create position success!");
          } else {
            throw message.error("Transaction failed");
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

  const onFinish = () => {
    if (collateralInput != undefined && amountBorrowInput != undefined) {
      borrow(Number(collateralInput), Number(amountBorrowInput));
    }
  };

  const onChangeCollateral = (value: any) => {
    if (isNaN(value)) {
      return;
    }
    const numericValue = BigInt(value);
    setCollateralInput(numericValue);
    setDisplayCollateralValue(formatEther(BigInt(numericValue)));
  };

  const onChangeBorrow = (value: any) => {
    if (isNaN(value)) {
      return;
    }
    const numericValue = BigInt(value);
    setAmountBorrowInput(numericValue);
    setDisplayAmountToBorrow(formatEther(BigInt(numericValue)));
  };

  useEffect(() => {
    fetchData();
  }, []);

  return (
    <div className="px-32">
      {!txLoading ? (
        <Form onFinish={onFinish} layout="vertical">
          <p className="text-white w-full text-left pt-10">
            Amount collateral:{" "}
            {displayCollateralValue
              ? Number(displayCollateralValue).toFixed(2)
              : 0}
          </p>
          <Form.Item name="collateral" initialValue={1}>
            <Slider
              min={1}
              max={Number(collateralBalance)}
              onChange={onChangeCollateral}
              value={typeof collateralInput === "number" ? collateralInput : 0}
              tooltip={{ open: false }}
            />
          </Form.Item>

          <p className="text-white w-full text-left">
            Amount tcUSD To Borrow:{" "}
            {displayAmountToBorrow
              ? Number(displayAmountToBorrow).toFixed(2)
              : 0}
          </p>
          <Form.Item name="tcUSD" initialValue={1}>
            <Slider
              min={1}
              max={Number(amountCanBorrow)}
              onChange={onChangeBorrow}
              value={
                typeof amountBorrowInput === "number" ? amountBorrowInput : 0
              }
              tooltip={{ open: false }}
            />
          </Form.Item>

          <div className="flex justify-between items-center">
            <Form.Item>
              <button
                type="submit"
                className="p-4 rounded-xl bg-black text-white hover:scale-90 transition-all"
              >
                Borrow
              </button>
            </Form.Item>
            <div className="flex justify-center items-center w-[50px] whitespace-nowrap gap-2 pb-8 pr-20">
              <p className="text-white">No deposit yet?</p>{" "}
              <button
                className="px-4 py-2 rounded-xl border text-white hover:scale-90 transition-all"
                onClick={() => setCurrent(current - 1)}
              >
                Previous
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

export default Step2;
