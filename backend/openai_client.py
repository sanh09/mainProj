import os


def _get_client():
    try:
        from openai import OpenAI
    except ImportError as exc:
        raise RuntimeError(
            "openai 패키지가 없습니다. `pip install openai`로 설치하세요."
        ) from exc
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("환경 변수에 OPENAI_API_KEY가 설정되어 있지 않습니다.")
    return OpenAI(api_key=api_key)


def chat_completion(
    prompt: str, model: str = "gpt-5.2", system_prompt: str | None = None
) -> str:
    client = _get_client()
    messages = []
    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})
    messages.append({"role": "user", "content": prompt})
    response = client.chat.completions.create(
        model=model,
        messages=messages,
    )
    return response.choices[0].message.content or ""
