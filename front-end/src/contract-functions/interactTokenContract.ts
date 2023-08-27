import {
  readContract,
  fetchBalance,
  writeContract,
  getNetwork,
  switchNetwork,
} from "@wagmi/core";
import MockTokenABI from "@/abis/MockTokenABI.json";
import { BigNumberish } from "ethers";

const getTokenName = async (address: any): Promise<string | null> => {
  try {
    const data: any = await readContract({
      address: address,
      abi: MockTokenABI,
      functionName: "name",
      args: [],
    });
    return data.toString();
  } catch (error) {
    console.log("Cannot get token name!");
    return null;
  }
};

const getTokenSymbol = async (address: any): Promise<string | null> => {
  try {
    const data: any = await readContract({
      address: address,
      abi: MockTokenABI,
      functionName: "symbol",
      args: [],
    });
    return data.toString();
  } catch (error) {
    console.log("Cannot get token symbol!");
    return null;
  }
};

const getTokenBalanceOf = async (
  address: any,
  token: any
): Promise<bigint | null> => {
  try {
    const data = await fetchBalance({
      address,
      token,
    });
    return data.value;
  } catch (error) {
    console.log("Cannot get token symbol!");
    return null;
  }
};

const tokenApprove = async (
  owner: any,
  token: string,
  spender: string,
  amount: bigint
): Promise<string | null> => {
  try {
    const { hash } = await writeContract({
      address: token as any,
      abi: MockTokenABI,
      functionName: "approve",
      args: [spender, amount],
      account: owner,
      chainId: 11155111,
    });
    return hash;
  } catch (error) {
    console.log("tokenApprove Failed!");
    return null;
  }
};

export { getTokenName, getTokenSymbol, getTokenBalanceOf, tokenApprove };
