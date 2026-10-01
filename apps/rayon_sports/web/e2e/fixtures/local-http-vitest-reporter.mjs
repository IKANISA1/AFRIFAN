/** Vitest's public reported-task API links each receipt to its actual result. */
export default class LocalHttpReporter {
  onTestRunEnd(modules, errors, reason) {
    const tests = modules.flatMap((module) => Array.from(module.children.allTests(), (test) => ({
      id: test.id, name: test.fullName, source: module.moduleId,
      result: test.result(), diagnostic: test.diagnostic(),
      assertions: test.meta().localRouteAssertions ?? [],
    })));
    process.stdout.write(`${JSON.stringify({
      format: "africlub-vitest-route-assertions-v1", reason,
      modules: modules.map((module) => ({ source: module.moduleId, state: module.state() })),
      unhandledErrors: errors, tests,
    })}\n`);
  }
}
