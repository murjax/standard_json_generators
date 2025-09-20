export function openModal(content) {
  const modalElement = this.element.querySelector('#modal');
  const modalContentElement = this.element.querySelector('#modal-inner-content');
  modalContentElement.appendChild(content);

  modalElement.classList.remove('hidden');
}

export function closeModal(event) {
  event?.preventDefault();

  const modalElement = this.element.querySelector('#modal');
  const modalContentElement = this.element.querySelector('#modal-inner-content');
  modalContentElement.innerHTML = '';
  modalElement.classList.add('hidden');
}

export function populateForm(form, modelName, record) {
  Object.keys(record).forEach((attribute) => {
    const input = form.querySelector(`#${modelName}_${attribute}`);
    if (input) {
      input.value = record[attribute];
    }
  });
}

export function populateFormRelationship(
  form,
  containerName,
  modelName,
  parentModelName,
  collection
) {
  const container = form.querySelector(`#${containerName}`);
  collection.forEach((record, index) => {
    let newRow;
    if (index === 0) {
      newRow = container.firstElementChild;
    } else {
      newRow = container.firstElementChild.cloneNode(true);
    }

    newRow.querySelectorAll('input').forEach((input) => {
      if (input.name.includes('destroy')) { return; }

      input.id = input.id.replace("0", index);
      input.name = input.name.replace("0", index);
      const fieldName = input.id.match(/[^_]+$/)[0]
      input.value = record[fieldName];
    });

    newRow.querySelector('.id-input')?.remove();
    newRow.querySelector('.destroy-input')?.remove();

    const idInput = document.createElement('input');
    idInput.type = 'hidden';
    idInput.value = record.id;
    idInput.id = `${parentModelName}_${modelName}_attributes_${index}_id`;
    idInput.name = `${parentModelName}[${modelName}_attributes][${index}][id]`;
    idInput.classList.add('id-input');
    newRow.appendChild(idInput);

    const destroyInput = document.createElement('input');
    destroyInput.type = 'hidden';
    destroyInput.value = '0';
    destroyInput.id = `${parentModelName}_${modelName}_attributes_${index}_destroy`;
    destroyInput.name = `${parentModelName}[${modelName}_attributes][${index}][_destroy]`;
    destroyInput.classList.add('destroy-input')
    newRow.appendChild(destroyInput);

    container.appendChild(newRow);
  });
}

export async function fetchRecord(id, modelName, pathName, options) {
  const recordResponse = await fetch(`/api/${pathName}/${id}`, {
    method: "GET",
    headers: {
      "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
      "Content-Type": "application/json"
    }
  });
  const record = await recordResponse.json();

  const included = [];

  if (options?.include) {
    const includePromises = [];
    options.include.forEach((collectionModelName) => {
      const includePromise = fetch(
        `/api/${collectionModelName}?filter_${modelName}_id=${id}`,
        {
          method: "GET",
          headers: {
            "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
            "Content-Type": "application/json"
          }
        }
      ).then((response) => response.json()
      ).then((data) => {
        const collectionData = {};
        collectionData[collectionModelName] = data.data;
        return collectionData;
      });

      includePromises.push(includePromise);
    });

    const includedData = await Promise.all(includePromises);
    includedData.forEach((collection) => included.push(collection));
  }

  const data = {};
  data[modelName] = record;
  data['included'] = included;

  return data;
}

export async function saveRecord(form, modelName) {
  const path = form.getAttribute('action');
  const method = form.getAttribute('method');

  const formData = new FormData(event.target.parentElement);
  const formProps = Object.fromEntries(formData);

  const singleBracketRegex = /^[^\[\]]+\[([^\[\]]+)\]$/;

  const formKeys = Object.keys(formProps).reduce((acc, key) => {
    const match = key.match(singleBracketRegex);

    if (match) {
      acc.push(match[1]);
    }

    return acc;
  }, []);

  const multiBracketRegex = /^\w+\[([^\]]+)\]\[([^\]]+)\]\[([^\]]+)\]$/
  const nestedAttrs = Object.keys(formProps).reduce((acc, key) => {
    const match = key.match(multiBracketRegex);

    if (match) {
      const field = match[1];
      const index = match[2];
      const innerField = match[3];
      acc[field] = acc[field] || {};
      acc[field][index] = acc[field][index] || {};
      acc[field][index][innerField] = formProps[key];
    }

    return acc;
  }, {});

  const attrBody = formKeys.reduce((acc, key) => {
    acc[key] = formProps[`${modelName}[${key}]`]
    return acc;
  }, {});

  const body = {};
  body[modelName] = {...attrBody, ...nestedAttrs};

  const response = await fetch(`/api${path}`, {
    method,
    headers: {
      "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  });

  if (response.status < 400) {
    this.closeModal();
  } else if (response.status < 500) {
    const responseData = await response.json();

    Object.keys(responseData.errors).forEach((key) => {
      const inputElement = form.querySelector(`#${modelName}_${key}`);
      const errorsElement = inputElement.parentElement.querySelector('.errors');
      errorsElement.innerHTML = responseData.errors[key][0];
    });
  } else {
    form.querySelector('.general-errors').innerHTML = 'Something went wrong. Please try again later.';
  }
}

export default {
  openModal,
  closeModal,
  populateForm,
  populateFormRelationship,
  fetchRecord,
  saveRecord
}
