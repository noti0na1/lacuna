# Lacuna

Typed, scope-aware LLM holes for the live Scala agent.

**[Preprint](https://arxiv.org/abs/2605.28617)**

## Idea

An agent action is a typed hole the LLM fills with code at execution time:

```scala
scala> agent[Int]("what is the sum of 1 to 100")
// the generated code: (1 to 100).sum
val res0: Int = 5050
```

`agent[T]("task")` asks the model to fill the call site with a Scala expression
of type `T`. The generated code is type-checked against the surrounding program
before it runs, so an ill-typed action is rejected with a compiler diagnostic
and never touches the environment; the diagnostic is fed back and the call
retries. Because a hole is ordinary code, holes compose: a generated body can use
variables and helpers in scope and open further `agent[...]` holes, giving sub-agents,
parallel decomposition, and multi-step planning as plain control flow.

## Examples

A hole is filled using the values and types already in scope. Here the model
reads the local `xs` and returns a `List[Int]`:

```scala
scala> val xs = List(0, 1, 2, 4, 7, 9, 10)
val xs: List[Int] = List(0, 1, 2, 4, 7, 9, 10)

scala> agent[List[Int]]("filter the prime number from xs")
// the generated code:
// xs.filter(n => n > 1 && (2 until n).forall(n % _ != 0))
val res1: List[Int] = List(2, 7)
```

Holes compose into typed *skills*: ordinary functions that mix plain Scala with
`agent` holes. This `review` skill lets the model enumerate issues and summarize
them, then plain code decides the verdict and returns structured, typed data:

```scala
scala> case class Finding(issue: String, severity: String, suggestion: String)
// defined case class Finding

scala> case class Review(summary: String, findings: List[Finding], approved: Boolean)
// defined case class Review

scala> def review(code: String): Review =
         // step 1: let the model enumerate concrete issues
         val findings = agent[List[Finding]](
           s"review this Scala code for bugs and smells; for each give issue, " +
           s"severity (low/medium/high), and a one-line suggestion:\n$code")
         // step 2: a one-sentence summary of what was found
         val summary = agent[String](s"summarize these review findings in one sentence: $findings")
         // step 3: plain code decides the verdict, blocking only on high severity
         val approved = !findings.exists(_.severity == "high")
         Review(summary, findings, approved)

def review(code: String): Review

scala> review("def avg(xs: List[Int]): Int = xs.sum / xs.size")
[agent] reviewing code for issues
[agent] summarizing findings
val res0: Review = Review(
  summary = "The findings are: Division by zero when list is empty (high) and Integer division truncates fractional part (medium).",
  findings = List(
    Finding(
      issue = "Division by zero when list is empty",
      severity = "high",
      suggestion = "Guard with xs.nonEmpty or return Option[Int]"
    ),
    Finding(
      issue = "Integer division truncates fractional part",
      severity = "medium",
      suggestion = "Use Double for average calculation"
    )
  ),
  approved = false
)
```

Now, we can ask the agent to review every code in a directory, and it will
read each file, call `review`, and write a summary report, automatically:

```scala
scala> agent[Any]("review every code in `/Users/user/project/src`")
[agent] reviewing A.scala
[agent] reviewing B.scala
[agent] reviewing C.scala
...
```

More in [`agent_examples.md`](agent_examples.md).

## Requirements

- A JDK (17+), `git`, and `sbt`.
- Latest [`scala-cli`](https://scala-cli.virtuslab.org/install) (preferred) or `scala` to launch the REPL.
- An API key for an OpenAI-compatible chat-completions endpoint.

## Setup

The agent runs on a custom Scala 3 compiler/REPL fork
([dynamic-eval-scala-3](https://github.com/noti0na1/dynamic-eval-scala-3)) that
adds the typed-hole `eval` machinery. Build and publish it to your local
ivy repo once:

```bash
./setup.sh
```

The build is heavy and can take several minutes.

## Configure

Copy the example config and add your key:

```bash
cp env.sh.example env.sh
# then edit env.sh: set AGENT_API_KEY (and AGENT_BASE_URL / AGENT_MODEL)
```

See [`env.sh.example`](env.sh.example) for every setting (model, reasoning,
temperature, recursion depth, attempt budget, transcript history).

## Run

```bash
./start.sh

Welcome to Scala 3.10.0-RC1-bin-SNAPSHOT-git-e9c4cff (17.0.16, Java OpenJDK 64-Bit Server VM).
Type in expressions for evaluation. Or try :help.

scala> 
```

## License

Apache License Version 2.0

See [LICENSE](LICENSE).
