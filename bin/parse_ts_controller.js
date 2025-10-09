#!/usr/bin/env node
/* eslint-disable */

const ts = require('typescript');
const fs = require('fs');

// Get filename from command line argument
const filename = process.argv[2];

if (!filename) {
  console.error('Usage: node parse_ts_controller.js <filename>');
  process.exit(1);
}

const sourceCode = fs.readFileSync(filename, 'utf8');

// Create TypeScript AST
const sourceFile = ts.createSourceFile(
  filename,
  sourceCode,
  ts.ScriptTarget.Latest,
  true // setParentNodes
);

const result = {
  targets: [],
  optionalTargets: [],
  values: [],
  valuesWithDefaults: [],
  methods: []
};

// Helper function to extract string literals from array
function extractArrayStringLiterals(node) {
  const items = [];

  if (ts.isArrayLiteralExpression(node)) {
    node.elements.forEach(element => {
      if (ts.isStringLiteral(element)) {
        items.push(element.text);
      }
    });
  }

  return items;
}

// Helper function to extract value names and check for defaults
function extractValuesWithDefaults(node) {
  const values = [];
  const valuesWithDefaults = [];

  if (ts.isObjectLiteralExpression(node)) {
    node.properties.forEach(prop => {
      if (ts.isPropertyAssignment(prop) && ts.isIdentifier(prop.name)) {
        const valueName = prop.name.text;
        values.push(valueName);

        // Check if value definition has a default property
        if (ts.isObjectLiteralExpression(prop.initializer)) {
          const hasDefault = prop.initializer.properties.some(innerProp => {
            return ts.isPropertyAssignment(innerProp) &&
                   ts.isIdentifier(innerProp.name) &&
                   innerProp.name.text === 'default';
          });

          if (hasDefault) {
            valuesWithDefaults.push(valueName);
          }
        }
      }
    });
  }

  return { values, valuesWithDefaults };
}

// Traverse AST to find class members
function visitNode(node) {
  // Look for class declaration
  if (ts.isClassDeclaration(node)) {
    node.members.forEach(member => {
      // Check for static properties
      if (ts.isPropertyDeclaration(member) &&
          member.modifiers?.some(m => m.kind === ts.SyntaxKind.StaticKeyword)) {

        const name = member.name.getText(sourceFile);

        // Extract static targets = [...]
        if (name === 'targets' && member.initializer) {
          result.targets = extractArrayStringLiterals(member.initializer);
        }

        // Extract static values = {...}
        if (name === 'values' && member.initializer) {
          const valuesData = extractValuesWithDefaults(member.initializer);
          result.values = valuesData.values;
          result.valuesWithDefaults = valuesData.valuesWithDefaults;
        }
      }

      // Check for readonly property declarations to find optional targets
      if (ts.isPropertyDeclaration(member) &&
          member.modifiers?.some(m => m.kind === ts.SyntaxKind.ReadonlyKeyword)) {

        const propertyName = member.name.getText(sourceFile);

        // Check if it's a hasXXXTarget property
        const hasTargetMatch = propertyName.match(/^has(\w+)Target$/);
        if (hasTargetMatch) {
          // Convert hasMenuTarget -> menu
          const targetName = hasTargetMatch[1].charAt(0).toLowerCase() + hasTargetMatch[1].slice(1);
          result.optionalTargets.push(targetName);
        }
      }

      // Check for method declarations
      if (ts.isMethodDeclaration(member) && ts.isIdentifier(member.name)) {
        const methodName = member.name.text;

        // Exclude lifecycle methods
        if (!['connect', 'disconnect', 'constructor'].includes(methodName)) {
          result.methods.push(methodName);
        }
      }
    });
  }

  // Continue traversing
  ts.forEachChild(node, visitNode);
}

// Start traversal
visitNode(sourceFile);

// Output JSON result
console.log(JSON.stringify(result));
