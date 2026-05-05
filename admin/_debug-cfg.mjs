import * as shared from "next/dist/server/config-shared.js";
const d = shared.defaultConfig;
const desc = Object.getOwnPropertyDescriptor(d, "generateBuildId");
console.log("descriptor:", desc);
console.log("is enumerable:", desc && desc.enumerable);
console.log("spread copy generateBuildId:", typeof ({ ...d }.generateBuildId));
