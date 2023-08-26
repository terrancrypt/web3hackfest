import { writeContract, readContract } from "@wagmi/core";
import EngineABI from "../abis/EngineABI.json";

const engineContract = {
  address: "0xDD15Ec62C853E492a6E31b7EBa2e9A2ECFBc123F",
  abi: EngineABI,
};

const getCurrentVaultId = async (): Promise<number> => {
  const data: any = await readContract({
    ...(engineContract as any),
    functionName: "getCurrentVaultId",
  });
  return Number(data);
};

const getVaultAddress = async (vaultId: number): Promise<string | null> => {
  try {
    const data: any = await readContract({
      ...(engineContract as any),
      functionName: "getVaultAddress",
      args: [vaultId],
    });
    return data.toString();
  } catch (error) {
    console.log("getVaultAddress Error!");
    return null;
  }
};

const getVaultBalance = async (vaultId: number): Promise<number> => {
  const data: any = await readContract({
    ...(engineContract as any),
    functionName: "getVaultBalance",
    args: [vaultId],
  });
  return Number(data);
};

const getUSDValueOfCollateral = async (
  collateral: string | null,
  amount: number
): Promise<number> => {
  const data: any = await readContract({
    ...(engineContract as any),
    functionName: "getUSDValueOfCollateral",
    args: [collateral, amount],
  });
  return Number(data);
};

const getUserVaultBalance = async (
  vauldId: number,
  userAddress: string
): Promise<number> => {
  const data: any = await readContract({
    ...(engineContract as any),
    functionName: "getCollateralDeposited",
    args: [vauldId],
    account: userAddress,
  });
  return Number(data);
};

const getTcUSDAmountCanBorrow = async (
  vaultId: number,
  userAddress: string
): Promise<number> => {
  const data: any = await readContract({
    ...(engineContract as any),
    functionName: "getAmountCanBorrow",
    args: [vaultId],
    account: userAddress,
  });
  return Number(data);
};

const depositCollateral = async (
  amountToDeposit: number,
  userAddress: string
): Promise<string> => {
  const { hash } = await writeContract({
    ...(engineContract as any),
    functionName: "depostionCollateral",
    args: [amountToDeposit],
    account: userAddress,
  });
  return hash.toString();
};

export {
  engineContract,
  getCurrentVaultId,
  getVaultAddress,
  getVaultBalance,
  getUSDValueOfCollateral,
  getUserVaultBalance,
  getTcUSDAmountCanBorrow,
  depositCollateral,
};
