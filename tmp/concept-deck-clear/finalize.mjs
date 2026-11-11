import fs from "node:fs/promises";
import path from "node:path";
import {pathToFileURL} from "node:url";

const root = process.cwd();
const dir = path.join(root,"tmp","concept-deck-clear");
const output = path.join(root,"output","presentations","algorythm_product_concept_v2.pptx");
const skill = process.env.CONCEPT_SKILL;
const helpers = path.join(skill,"container_tools");
const {finalizePresentation} = await import(pathToFileURL(path.join(helpers,"artifact_tool_utils.mjs")).href);
await fs.mkdir(path.dirname(output),{recursive:true});
const nativeLink = fs.link;
fs.link = async (source, destination) => {
  try {
    await nativeLink(source, destination);
  } catch (error) {
    if (error.code !== "EPERM" || destination !== output || !source.endsWith(".validated")) throw error;
    await fs.copyFile(source, destination, fs.constants.COPYFILE_EXCL);
  }
};
const result = await finalizePresentation({
  workspaceDir:root,
  candidatePath:path.join(dir,"linked.pptx"),
  finalPath:output,
  pythonExecutable:process.env.RUNTIME_PYTHON,
  integrityValidatorPath:path.join(helpers,"inspect_presentation_package_integrity.py"),
  layoutValidatorPath:path.join(helpers,"inspect_presentation_layout_geometry.py"),
  layoutArgs:["--expected-slide-size-emu","12192000,6858000","--validate-bullet-geometry","--validate-heading-fit"],

  fontPolicy:{basis:"design",families:["Calibri"]},
  verifyArtifactToolImport:true,
  receiptPath:path.join(dir,"validation.json"),
});
console.log(JSON.stringify(result,null,2));
