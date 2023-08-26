import {
  engineContract,
  getTcUSDAmountCanBorrow,
  getUSDValueOfCollateral,
  getVaultAddress,
} from "@/contract-functions/interactEngineContract";
import { Form, InputNumber, Slider, Spin, message } from "antd";
import { useRouter } from "next/router";
import React, { useState, useEffect, use } from "react";
import { getAccount, waitForTransaction } from "@wagmi/core";
import {
  getTokenBalanceOf,
  tokenApprove,
} from "@/contract-functions/interactTokenContract";

interface Step1Props {
  current: number;
  setCurrent: (value: number) => void;
}

const Step1: React.FC<Step1Props> = ({ current, setCurrent }) => {
  const {
    query: { vaultId },
  } = useRouter();
  const account = getAccount();
  const [inputValue, setInputValue] = useState(1);
  const [collateral, setCollateral] = useState("");
  const [accountBalance, setAccountBalance] = useState(0);
  const [amountCanBorrow, setAmountCanBorrow] = useState(0);
  const [txLoading, setTxLoading] = useState(false);

  const onChange = (value: any) => {
    if (isNaN(value)) {
      return;
    }
    setInputValue(value);
  };

  const fetchData = async () => {
    try {
      const collateral = await getVaultAddress(Number(vaultId));
      let accountBalance: string | null;
      if (account.connector != undefined) {
        accountBalance = await getTokenBalanceOf(account.address, collateral);
        const collateralPrice = await getUSDValueOfCollateral(collateral, 1);
        const amountTcUSDCanBorrow =
          (collateralPrice * Number(accountBalance) * 45) / 100;
        setAccountBalance(Number(accountBalance));
        setAmountCanBorrow(amountTcUSDCanBorrow);
      }
      if (collateral != null) {
        setCollateral(collateral);
      }
    } catch {
      message.error("Cannot fetch data!");
    }
  };

  const onFinish = (values: any) => {
    if (values.slider != null) {
      approveEngine(Number(values.slider));
    }
  };

  const approveEngine = async (amount: number) => {
    try {
      setTxLoading(true);
      const hash = await tokenApprove(
        account.address,
        collateral,
        engineContract.address,
        amount
      );
      if (hash == null) {
        message.error("Transaction Error");
      }
      const wait: any = await waitForTransaction({
        confirmations: 1,
        hash: hash as any,
      });
      if (wait.status == "success") {
        message.success("Approve success!");
        setCurrent(current + 1);
      } else {
        message.error("Transaction failed");
      }
    } catch (error) {
      console.log(error);
      message.error("Cannot send transaction");
    } finally {
      setTxLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [account.status]);
  return (
    <div className="px-32 pt-16">
      {!txLoading ? (
        <Form onFinish={onFinish} layout="vertical">
          <div className="flex">
            <Form.Item
              name="slider"
              className="flex-grow"
              label="Amount Collateral"
            >
              <Slider
                min={1}
                max={accountBalance}
                onChange={onChange}
                value={typeof inputValue === "number" ? inputValue : 0}
              />
            </Form.Item>

            <Form.Item
              name="slider"
              label={`Max: ${accountBalance}`}
              labelAlign="right"
            >
              <InputNumber
                min={1}
                max={accountBalance}
                style={{ margin: "0 16px" }}
                value={inputValue}
                onChange={onChange}
              />
            </Form.Item>
          </div>
          <div className="flex">
            <Form.Item name="slider" className="flex-grow" label="Amount tcUSD">
              <Slider
                min={1}
                max={amountCanBorrow}
                onChange={onChange}
                value={typeof inputValue === "number" ? inputValue : 0}
              />
            </Form.Item>

            <Form.Item
              name="slider"
              label={`Max: ${amountCanBorrow}`}
              labelAlign="right"
            >
              <InputNumber
                min={1}
                max={amountCanBorrow}
                style={{ margin: "0 16px" }}
                value={inputValue}
                onChange={onChange}
              />
            </Form.Item>
          </div>

          <Form.Item>
            <button
              type="submit"
              className="p-4 rounded-xl bg-black text-white hover:scale-90 transition-all"
            >
              Approve
            </button>
          </Form.Item>
        </Form>
      ) : (
        <>
          <Spin
            size="large"
            tip="Transaction in progress..."
            spinning={txLoading}
          >
            <div className="content" />
          </Spin>
        </>
      )}
    </div>
  );
};

export default Step1;
